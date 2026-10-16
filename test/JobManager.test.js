const { expect } = require("chai");
const { ethers, network } = require("hardhat");

const USDC = (n) => BigInt(Math.round(n * 1e6));
const RELAYER = ethers.id("RELAYER_ROLE");
const VAULT_ROLE = ethers.id("VAULT_ROLE");
const ADMIN_ROLE = ethers.id("ADMIN_ROLE");
const MINTER_ROLE = ethers.id("MINTER_ROLE");
const WINDOW = 600; // 10 min, the testnet default
const Status = { Open: 0, Submitted: 1, Completed: 2, Failed: 3, Disputed: 4, Expired: 5 };

async function expectRevert(promise, text) {
  try {
    await promise;
  } catch (e) {
    const msg = `${e.shortMessage || ""} ${e.message || ""} ${e.reason || ""}`;
    if (!msg.includes(text)) {
      throw new Error(`reverted with "${msg.slice(0, 300)}" but expected "${text}"`);
    }
    return;
  }
  throw new Error(`expected revert containing "${text}" but the call succeeded`);
}

async function warp(seconds) {
  await network.provider.send("evm_increaseTime", [seconds]);
  await network.provider.send("evm_mine");
}

// Move to 01:00 UTC of the next day so same-day cap tests cannot straddle midnight.
async function alignToDayStart() {
  const b = await ethers.provider.getBlock("latest");
  const next = (Math.floor(b.timestamp / 86400) + 1) * 86400 + 3600;
  await network.provider.send("evm_setNextBlockTimestamp", [next]);
  await network.provider.send("evm_mine");
}

async function deploy(withRoles = true) {
  const [owner, treasury, provider, client, bot, stranger] = await ethers.getSigners();
  const usdc = await ethers.deployContract("TestUSDC");
  const badge = await ethers.deployContract("RepBadge");
  const score = await ethers.deployContract("RepScore");
  const addr = async (c) => c.getAddress();
  const vault = await ethers.deployContract("RepVault", [
    await addr(usdc), await addr(badge), await addr(score), treasury.address,
  ]);
  await badge.grantRole(MINTER_ROLE, await addr(vault));
  await score.grantRole(VAULT_ROLE, await addr(vault));

  const jm = await ethers.deployContract("JobManager", [
    await addr(usdc), await addr(vault), await addr(score), owner.address, WINDOW,
  ]);
  if (withRoles) {
    await score.grantRole(RELAYER, await addr(jm));
    await vault.grantRole(ADMIN_ROLE, await addr(jm));
  }

  await usdc.mint(provider.address, USDC(1000));
  await usdc.mint(client.address, USDC(1000));
  await usdc.connect(provider).approve(await addr(vault), USDC(100));
  await vault.connect(provider).stake(provider.address, USDC(100)); // 99 after 1% fee

  return { owner, treasury, provider, client, bot, stranger, usdc, badge, score, vault, jm };
}

async function newJob(ctx, amount = USDC(10), who = ctx.client) {
  const { jm, usdc } = ctx;
  await usdc.connect(who).approve(await jm.getAddress(), amount);
  await jm.connect(who).createJob(ctx.provider.address, ethers.id("task"), amount);
  return jm.jobCounter();
}

async function jobPts(ctx) {
  return (await ctx.score.agentData(ctx.provider.address)).jobPts;
}

async function eventNames(jm, tx) {
  const rc = await tx.wait();
  return rc.logs.map((l) => {
    try { return jm.interface.parseLog(l).name; } catch { return null; }
  });
}

describe("JobManager", function () {
  describe("happy path: auto-finalize", function () {
    it("pays the provider and adds +40 rep once the window passes, via a third party", async function () {
      const ctx = await deploy();
      const { jm, usdc, provider, client, bot } = ctx;
      const id = await newJob(ctx, USDC(10));
      const before = await usdc.balanceOf(provider.address);

      await jm.connect(provider).submitResult(id, ethers.id("result"));
      await expectRevert(jm.connect(bot).finalize(id), "window open");

      await warp(WINDOW + 1);
      await jm.connect(bot).finalize(id); // the cron bot holds no special role

      expect((await jm.jobs(id)).status).to.equal(BigInt(Status.Completed));
      expect((await usdc.balanceOf(provider.address)) - before).to.equal(USDC(10));
      expect(await usdc.balanceOf(await jm.getAddress())).to.equal(0n);
      expect(await jobPts(ctx)).to.equal(40n);
    });

    it("client can approve early", async function () {
      const ctx = await deploy();
      const { jm, usdc, provider, client, stranger } = ctx;
      const id = await newJob(ctx);
      await jm.connect(provider).submitResult(id, ethers.id("r"));
      await expectRevert(jm.connect(stranger).approve(id), "not client");
      const before = await usdc.balanceOf(provider.address);
      await jm.connect(client).approve(id);
      expect((await usdc.balanceOf(provider.address)) - before).to.equal(USDC(10));
      expect(await jobPts(ctx)).to.equal(40n);
    });

    it("cannot finalize twice", async function () {
      const ctx = await deploy();
      const { jm, provider, bot } = ctx;
      const id = await newJob(ctx);
      await jm.connect(provider).submitResult(id, ethers.id("r"));
      await warp(WINDOW + 1);
      await jm.connect(bot).finalize(id);
      await expectRevert(jm.connect(bot).finalize(id), "not submitted");
    });
  });

  describe("anti-farming and validation", function () {
    it("blocks self-dealing", async function () {
      const ctx = await deploy();
      const { jm, usdc, provider } = ctx;
      await usdc.connect(provider).approve(await jm.getAddress(), USDC(10));
      await expectRevert(
        jm.connect(provider).createJob(provider.address, ethers.id("x"), USDC(10)),
        "self-dealing"
      );
    });

    it("enforces the 5 USDC minimum escrow", async function () {
      const ctx = await deploy();
      const { jm, usdc, client, provider } = ctx;
      await usdc.connect(client).approve(await jm.getAddress(), USDC(4));
      await expectRevert(
        jm.connect(client).createJob(provider.address, ethers.id("x"), USDC(4)),
        "below minimum"
      );
    });

    it("requires the provider to be staked", async function () {
      const ctx = await deploy();
      const { jm, usdc, client, stranger } = ctx;
      await usdc.connect(client).approve(await jm.getAddress(), USDC(10));
      await expectRevert(
        jm.connect(client).createJob(stranger.address, ethers.id("x"), USDC(10)),
        "not staked"
      );
    });

    it("only the provider can submit", async function () {
      const ctx = await deploy();
      const { jm, client } = ctx;
      const id = await newJob(ctx);
      await expectRevert(jm.connect(client).submitResult(id, ethers.id("r")), "not provider");
    });

    it("pays but stops scoring after 3 jobs per client-provider pair per day", async function () {
      const ctx = await deploy();
      const { jm, provider, bot } = ctx;
      await alignToDayStart();
      for (let i = 0; i < 3; i++) {
        const id = await newJob(ctx);
        await jm.connect(provider).submitResult(id, ethers.id("r" + i));
        await warp(WINDOW + 1);
        await jm.connect(bot).finalize(id);
      }
      expect(await jobPts(ctx)).to.equal(120n);

      const id4 = await newJob(ctx);
      await jm.connect(provider).submitResult(id4, ethers.id("r4"));
      await warp(WINDOW + 1);
      const tx = await jm.connect(bot).finalize(id4);
      expect(await eventNames(jm, tx)).to.include("NotScored");
      expect(await jobPts(ctx)).to.equal(120n); // unchanged
      expect((await jm.jobs(id4)).status).to.equal(BigInt(Status.Completed)); // still paid
    });
  });

  describe("disputes", function () {
    it("dispute inside the window blocks finalize", async function () {
      const ctx = await deploy();
      const { jm, provider, client, bot } = ctx;
      const id = await newJob(ctx);
      await jm.connect(provider).submitResult(id, ethers.id("r"));
      await jm.connect(client).dispute(id);
      await warp(WINDOW + 1);
      await expectRevert(jm.connect(bot).finalize(id), "not submitted");
      expect((await jm.jobs(id)).status).to.equal(BigInt(Status.Disputed));
    });

    it("cannot dispute after the window closes", async function () {
      const ctx = await deploy();
      const { jm, provider, client } = ctx;
      const id = await newJob(ctx);
      await jm.connect(provider).submitResult(id, ethers.id("r"));
      await warp(WINDOW + 1);
      await expectRevert(jm.connect(client).dispute(id), "window closed");
    });

    it("only the client can dispute", async function () {
      const ctx = await deploy();
      const { jm, provider, stranger } = ctx;
      const id = await newJob(ctx);
      await jm.connect(provider).submitResult(id, ethers.id("r"));
      await expectRevert(jm.connect(stranger).dispute(id), "not client");
    });

    it("owner rules for the provider: paid and +40", async function () {
      const ctx = await deploy();
      const { jm, usdc, provider, client, owner } = ctx;
      const id = await newJob(ctx);
      await jm.connect(provider).submitResult(id, ethers.id("r"));
      await jm.connect(client).dispute(id);
      const before = await usdc.balanceOf(provider.address);
      await jm.connect(owner).resolveDispute(id, true);
      expect((await usdc.balanceOf(provider.address)) - before).to.equal(USDC(10));
      expect(await jobPts(ctx)).to.equal(40n);
    });

    it("owner rules for the client: refund, 10% slash, half of slash to client", async function () {
      const ctx = await deploy();
      const { jm, usdc, vault, provider, client, owner } = ctx;
      const id = await newJob(ctx);
      await jm.connect(provider).submitResult(id, ethers.id("r"));
      await jm.connect(client).dispute(id);
      await jm.connect(owner).resolveDispute(id, false);

      expect((await jm.jobs(id)).status).to.equal(BigInt(Status.Failed));
      // 1000 start - 10 escrow + 10 refund + 4.95 (half of 9.9 slashed)
      expect(await usdc.balanceOf(client.address)).to.equal(USDC(1004.95));
      expect(await vault.getStakeBalance(provider.address)).to.equal(USDC(89.1));
    });

    it("only the owner can resolve", async function () {
      const ctx = await deploy();
      const { jm, provider, client, stranger } = ctx;
      const id = await newJob(ctx);
      await jm.connect(provider).submitResult(id, ethers.id("r"));
      await jm.connect(client).dispute(id);
      await expectRevert(jm.connect(stranger).resolveDispute(id, false), "OwnableUnauthorizedAccount");
    });
  });

  describe("expiry", function () {
    it("refunds the client if the provider never submits, with no rep penalty", async function () {
      const ctx = await deploy();
      const { jm, usdc, client, bot } = ctx;
      const id = await newJob(ctx, USDC(10));
      await expectRevert(jm.connect(bot).expire(id), "still open");
      await warp(7 * 86400 + 1);
      await jm.connect(bot).expire(id);
      expect(await usdc.balanceOf(client.address)).to.equal(USDC(1000));
      expect((await jm.jobs(id)).status).to.equal(BigInt(Status.Expired));
      expect(await jobPts(ctx)).to.equal(0n);
    });

    it("provider cannot submit after the submit window", async function () {
      const ctx = await deploy();
      const { jm, provider } = ctx;
      const id = await newJob(ctx);
      await warp(7 * 86400 + 1);
      await expectRevert(jm.connect(provider).submitResult(id, ethers.id("late")), "window over");
    });
  });

  describe("safety", function () {
    it("escrow still pays out if the roles were never granted (rep update is skipped, flagged)", async function () {
      const ctx = await deploy(false); // no RELAYER_ROLE / ADMIN_ROLE
      const { jm, usdc, provider, bot } = ctx;
      const id = await newJob(ctx);
      await jm.connect(provider).submitResult(id, ethers.id("r"));
      await warp(WINDOW + 1);
      const before = await usdc.balanceOf(provider.address);
      const tx = await jm.connect(bot).finalize(id);
      expect(await eventNames(jm, tx)).to.include("ReputationCallFailed");
      expect((await usdc.balanceOf(provider.address)) - before).to.equal(USDC(10));
      expect(await jobPts(ctx)).to.equal(0n);
    });

    it("dispute window is bounded", async function () {
      const ctx = await deploy();
      const { jm, owner, stranger } = ctx;
      await expectRevert(jm.connect(owner).setDisputeWindow(60), "bad window");
      await expectRevert(jm.connect(owner).setDisputeWindow(8 * 86400), "bad window");
      await jm.connect(owner).setDisputeWindow(86400);
      expect(await jm.disputeWindow()).to.equal(86400n);
      await expectRevert(jm.connect(stranger).setDisputeWindow(3600), "OwnableUnauthorizedAccount");
    });
  });
});
