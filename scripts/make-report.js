// Runs in CI after `hardhat test`. Writes ci-report/JobManager.json and ci-report/deploy.html
const fs = require("fs");
const path = require("path");

const art = JSON.parse(
  fs.readFileSync(path.join("artifacts", "contracts", "JobManager.sol", "JobManager.json"), "utf8")
);
fs.mkdirSync("ci-report", { recursive: true });
fs.writeFileSync(
  path.join("ci-report", "JobManager.json"),
  JSON.stringify({ abi: art.abi, bytecode: art.bytecode }, null, 2)
);

const html = `<!doctype html>
<html lang="en"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>rep24 · JobManager setup</title>
<script src="https://cdnjs.cloudflare.com/ajax/libs/ethers/5.7.2/ethers.umd.min.js"></script>
<style>
:root{--bg:#f6f5ff;--card:#fff;--text:#14142b;--mut:#6b6b85;--blue:#2563eb;--red:#dc2626;--green:#059669;--line:#e4e2f5}
@media (prefers-color-scheme:dark){:root{--bg:#0f0f1c;--card:#191930;--text:#f0f0ff;--mut:#9a9ab8;--line:#2b2b4a}}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--text);font:15px/1.45 system-ui,sans-serif;padding:16px}
.card{background:var(--card);border:1px solid var(--line);border-radius:14px;padding:16px;margin:0 auto 14px;max-width:560px}
h1{font-size:20px;margin:0 0 6px}h2{font-size:15px;margin:0 0 8px}p{margin:6px 0;color:var(--mut)}
label{display:block;font-size:12px;color:var(--mut);margin:10px 0 4px}
input{width:100%;padding:10px;border-radius:10px;border:1px solid var(--line);background:transparent;color:var(--text);font:13px ui-monospace,monospace}
button{width:100%;margin-top:10px;padding:13px;border:0;border-radius:12px;background:var(--blue);color:#fff;font-weight:700;font-size:15px}
button:disabled{opacity:.5}.warn{border-color:var(--red)}.warn b{color:var(--red)}
#log{font:12px ui-monospace,monospace;white-space:pre-wrap;word-break:break-all}.ok{color:var(--green)}.err{color:var(--red)}
</style></head><body>
<div class="card warn"><h1>JobManager setup</h1>
<p><b>Admin wallet only.</b> This page does exactly 3 things: deploys the new JobManager, grants it RELAYER_ROLE on RepScore, grants it ADMIN_ROLE on RepVault. Nothing else. Open it inside the MetaMask browser on Base Sepolia. Delete this file after use.</p></div>

<div class="card"><h2>0 · Connect</h2><button id="bConnect">Connect wallet</button><p id="who"></p></div>

<div class="card"><h2>1 · Deploy</h2>
<label>USDC</label><input id="usdc" value="0xDdB4dA5EAF928b8dfCAe8eF5B758b4A9DC1695de">
<label>RepVault</label><input id="vault" value="0x47b8055E25FBda1cfEe3b8d6D0ED4c2ccbe947E5">
<label>RepScore</label><input id="score" value="0x2Bcc43973B600f29E0Cd8Dc740B8b0c3043F08c3">
<label>Dispute window (seconds) — 600 testnet, 86400 mainnet</label><input id="win" value="600" inputmode="numeric">
<button id="bDeploy">Deploy JobManager</button></div>

<div class="card"><h2>2 · Grant roles</h2>
<label>New JobManager address</label><input id="jm" placeholder="filled after step 1">
<button id="bRel">Grant RELAYER_ROLE on RepScore</button>
<button id="bAdm">Grant ADMIN_ROLE on RepVault</button>
<button id="bChk">Check both roles</button></div>

<div class="card"><h2>Log</h2><div id="log"></div></div>

<script>
const ABI=${JSON.stringify(art.abi)};
const BYTECODE=${JSON.stringify(art.bytecode)};
const ROLE_ABI=['function grantRole(bytes32,address)','function hasRole(bytes32,address) view returns (bool)'];
let signer,user;
const $=id=>document.getElementById(id);
function log(m,c){const d=document.createElement('div');if(c)d.className=c;d.textContent=new Date().toLocaleTimeString('en-US',{hour12:false})+' '+m;$('log').prepend(d);}
async function connect(){
  if(!window.ethereum){log('Open this page inside the MetaMask browser','err');return false;}
  try{await ethereum.request({method:'eth_requestAccounts'});
    try{await ethereum.request({method:'wallet_switchEthereumChain',params:[{chainId:'0x14a34'}]});}catch(e){log('Switch to Base Sepolia manually: '+e.message,'err');return false;}
    const p=new ethers.providers.Web3Provider(window.ethereum);signer=p.getSigner();user=await signer.getAddress();
    $('who').textContent='Connected: '+user;log('Connected '+user,'ok');return true;
  }catch(e){log('Connect failed: '+e.message,'err');return false;}
}
async function guard(fn,btn){if(!signer&&!(await connect()))return;btn.disabled=true;try{await fn();}catch(e){log('Failed: '+(e.reason||e.message),'err');}btn.disabled=false;}
$('bConnect').onclick=connect;
$('bDeploy').onclick=function(){guard(async()=>{
  const ad=['usdc','vault','score'].map(k=>$(k).value.trim());
  if(!ad.every(a=>ethers.utils.isAddress(a))){log('Bad address in the form','err');return;}
  const w=parseInt($('win').value,10);if(!(w>=600&&w<=604800)){log('Window must be 600 to 604800','err');return;}
  log('Deploying… confirm in MetaMask');
  const f=new ethers.ContractFactory(ABI,BYTECODE,signer);
  const c=await f.deploy(ad[0],ad[1],ad[2],user,w);
  log('Sent, waiting for confirmation…');await c.deployed();
  $('jm').value=c.address;log('Deployed JobManager: '+c.address,'ok');
},this);};
function jmAddr(){const a=$('jm').value.trim();if(!ethers.utils.isAddress(a)){log('Enter the JobManager address first','err');return null;}return a;}
$('bRel').onclick=function(){guard(async()=>{const a=jmAddr();if(!a)return;
  const c=new ethers.Contract($('score').value.trim(),ROLE_ABI,signer);
  const tx=await c.grantRole(ethers.utils.id('RELAYER_ROLE'),a);log('Sent…');await tx.wait();log('RELAYER_ROLE granted ✓','ok');},this);};
$('bAdm').onclick=function(){guard(async()=>{const a=jmAddr();if(!a)return;
  const c=new ethers.Contract($('vault').value.trim(),ROLE_ABI,signer);
  const tx=await c.grantRole(ethers.utils.id('ADMIN_ROLE'),a);log('Sent…');await tx.wait();log('ADMIN_ROLE granted ✓','ok');},this);};
$('bChk').onclick=function(){guard(async()=>{const a=jmAddr();if(!a)return;
  const s=new ethers.Contract($('score').value.trim(),ROLE_ABI,signer);
  const v=new ethers.Contract($('vault').value.trim(),ROLE_ABI,signer);
  const r=await s.hasRole(ethers.utils.id('RELAYER_ROLE'),a);const m=await v.hasRole(ethers.utils.id('ADMIN_ROLE'),a);
  log('RELAYER_ROLE on RepScore: '+r,r?'ok':'err');log('ADMIN_ROLE on RepVault: '+m,m?'ok':'err');},this);};
</script></body></html>`;
fs.writeFileSync(path.join("ci-report", "deploy.html"), html);
console.log("report written; bytecode bytes:", (art.bytecode.length - 2) / 2);
