const { ethers } = require("hardhat")

async function main() {
  const stakeContract = await ethers.getContractAt("MetaNodeStake", "0xcB595Df4186287e8Dc6227b633714E5CF062599c")

  // 6️⃣ 查询 MetaNode 代币合约地址
  const metaNodeToken = await stakeContract.MetaNode()
  console.log("MetaNodeToken:", metaNodeToken)
}

main()
