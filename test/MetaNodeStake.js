const { ethers, network } = require("hardhat")
const { parseEther } = ethers

async function main() {
  const [deployer] = await ethers.getSigners()
  const userAddress = "0xcB595Df4186287e8Dc6227b633714E5CF062599c"
  const metaNodeStake = await ethers.getContractAt("MetaNodeStake", userAddress)
  // 6️⃣ 存款 ETH
  console.log("\n🔄 步骤 5: 存入 1 ETH 到质押池...")
  const depositTx = await metaNodeStake.depositETH({
    value: parseEther("0.00001"),
  })
  await depositTx.wait()
  console.log("✅ 存款成功，金额: 1 ETH")

  // 查看用户状态
  const user = await metaNodeStake.userInfo(0, deployer.address)
  console.log("\n👤 用户质押状态:")
  console.log("   - stAmount:", user.amount, "wei")
  console.log("   - finishedMetaNode:", user.finishedMetaNode)
  console.log("   - pendingMetaNode:", user.pendingMetaNode)

  // // 8️⃣ 更新池子（massUpdatePools）
  // console.log("\n🔄 步骤 7: 调用 massUpdatePools...")
  // await metaNodeStake.massUpdatePools()
  // const updatedPool = await metaNodeStake.pool(0)
  // console.log("✅ massUpdatePools 完成")
  // console.log("   - 更新后 lastRewardBlock:", updatedPool.lastRewardBlock.toString())

  // 9️⃣ 取消质押（unstake）
  console.log("\n🔄 步骤 8: 申请取款0.00003 ETH...")
  const unstakeTx = await metaNodeStake.unstake(0, parseEther("0.00003"))
  await unstakeTx.wait()
  console.log("✅ 取款申请成功，金额: 0.5 ETH")

  // 查看用户状态
  const userAfterUnstake = await metaNodeStake.userInfo(0, deployer.address)
  console.log("\n👤 取款后用户状态:")
  console.log("   - stAmount:", userAfterUnstake.amount)
  console.log("   - pendingMetaNode:", userAfterUnstake.pendingMetaNode)

  // 1️⃣0️⃣ 提现（withdraw）
  console.log("\n🔄 步骤 10: 执行提现...")
  const withdrawTx = await metaNodeStake.withdraw(0)
  await withdrawTx.wait()
  console.log("✅ 提现成功，ETH 已退回钱包")
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
