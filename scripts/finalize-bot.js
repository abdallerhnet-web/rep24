// Permissionless keeper: finalizes jobs whose dispute window has passed and
// expires jobs the provider never submitted. The wallet needs gas only, no roles.
const { ethers } = require("ethers");

const RPC = process.env.RPC_URL || "https://sepolia.base.org";
const JM = process.env.JOB_MANAGER_ADDRESS;
const KEY = process.env.RELAYER_PRIVATE_KEY;

if (!JM || !KEY) {
  console.log("Bot not configured (needs JOB_MANAGER_ADDRESS variable and RELAYER_PRIVATE_KEY secret). Skipping.");
  process.exit(0);
}

const ABI = [
  "function jobCounter() view returns (uint256)",
  "function jobs(uint256) view returns (address client,address provider,bytes32 referenceId,uint256 escrowAmount,uint8 status,uint256 createdAt,bytes32 resultHash,uint256 finalizeAfter,uint256 submitBy)",
  "function finalize(uint256)",
  "function expire(uint256)",
];

async function main() {
  const provider = new ethers.JsonRpcProvider(RPC);
  const wallet = new ethers.Wallet(KEY, provider);
  const jm = new ethers.Contract(JM, ABI, wallet);
  const now = (await provider.getBlock("latest")).timestamp;
  const n = Number(await jm.jobCounter());
  const from = Math.max(1, n - 300);
  console.log(`jobs=${n}, scanning ${from}..${n}, chain time=${now}`);

  let acted = 0;
  for (let id = from; id <= n; id++) {
    const j = await jm.jobs(id);
    const status = Number(j.status);
    let fn = null;
    if (status === 1 && BigInt(now) >= j.finalizeAfter) fn = "finalize";
    else if (status === 0 && BigInt(now) > j.submitBy) fn = "expire";
    if (!fn) continue;
    try {
      await jm[fn].staticCall(id); // dry run, avoids wasting gas on a revert
      const tx = await jm[fn](id);
      await tx.wait();
      acted++;
      console.log(`${fn}(${id}) ok ${tx.hash}`);
    } catch (e) {
      console.log(`${fn}(${id}) failed: ${e.shortMessage || e.message}`);
    }
  }
  console.log(`done, ${acted} job(s) processed`);
}

main().catch((e) => { console.error(e); process.exit(1); });
