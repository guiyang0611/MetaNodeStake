const { ethers, network } = require("hardhat")
const { parseEther } = ethers

async function main() {
  const [deployer] = await ethers.getSigners()
  const userAddress = "0xcB595Df4186287e8Dc6227b633714E5CF062599c"
  const metaNodeStake = await ethers.getContractAt("MetaNodeStake", userAddress)

  // 1️⃣0️⃣ 提现（withdraw）
  console.log("\n🔄 步骤 10: 执行提现...")
  const withdrawTx = await metaNodeStake.withdraw(0)
  await withdrawTx.wait()
  console.log("✅ 提现成功，ETH 已退回钱包")

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
