const { ethers, network } = require("hardhat")
const { parseEther } = ethers

async function main() {
  const [deployer] = await ethers.getSigners()
  const stakeAddress = "0xcB595Df4186287e8Dc6227b633714E5CF062599c"
  const metaNodeStake = await ethers.getContractAt("MetaNodeStake", stakeAddress)

  const MetaNodeAddress = "0x5dCaF1200172839fd266273846B590c4a1669207"
  const metaNode = await ethers.getContractAt("MetaNodeToken", MetaNodeAddress)

  // 1️⃣1️⃣ 领取奖励前：给合约转入 MetaNode 代币作为奖励
  console.log("\n🔄 步骤 11: 向质押合约转入 MetaNode 代币作为奖励...")
  const rewardAmount = parseEther("1000")
  const tx = await metaNode.transfer(stakeAddress, rewardAmount)
  await tx.wait()
  const contractMetaNodeBalance = await metaNode.balanceOf(stakeAddress)
  console.log("✅ 转入成功，合约 MetaNode 余额:", contractMetaNodeBalance)

  // 1️⃣2️⃣ 领取奖励
  console.log("\n🔄 步骤 12: 领取质押奖励...")
  const preClaimBalance = await metaNode.balanceOf(deployer.address)
  const claimTx = await metaNodeStake.claim(0)
  await claimTx.wait()
  const postClaimBalance = await metaNode.balanceOf(deployer.address)
  const received = postClaimBalance - preClaimBalance
  console.log("✅ 奖励领取成功！")
  console.log("   - 领取 MetaNode 数量:", ethers.formatEther(received))

  // 查看用户状态
  const userAfterUnstake = await metaNodeStake.userInfo(0, deployer.address)
  console.log("\n👤 取款后用户状态:")
  console.log("   - stAmount:", userAfterUnstake.amount)
  console.log("   - pendingMetaNode:", userAfterUnstake.pendingMetaNode)

  // 🎉 完成
  console.log("\n🎉 模拟运行完成！所有流程执行成功！")
}

// ✅ 主函数启动
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ 脚本执行出错:", error)
    process.exit(1)
  })
