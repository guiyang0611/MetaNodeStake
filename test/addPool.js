const { ethers } = require("hardhat")

async function main() {
  const metaNodeStake = await ethers.getContractAt("MetaNodeStake", "0xcB595Df4186287e8Dc6227b633714E5CF062599c")
  // 4️⃣ 添加池子（native ETH）
  console.log("\n🔄 步骤 4: 添加 ETH 质押池...")
  const stTokenAddress = ethers.ZeroAddress // ETH
  const poolWeight = 100
  const minDepositAmount = 100
  const withdrawLockedBlocks = 100
  const withUpdate = true

  const startBlock = await metaNodeStake.unlockBlocks()
  const currentBlock = await ethers.provider.getBlockNumber()
  console.log("   - 当前区块:", currentBlock)
  console.log("   - 开始区块:", startBlock)
  if (currentBlock < startBlock) {
    console.error(`❌ 错误：当前区块 ${currentBlock} < unlockBlocks ${unlockBlocks}，质押尚未开始！`)
    console.error("💡 请等待区块高度超过 unlockBlocks，或重新部署并设置 unlockBlocks <= 当前区块")
    process.exit(1)
  } else {
    console.log("✅ 当前区块 >= unlockBlocks，可以安全调用 addPool")
  }

  const txAddPool = await metaNodeStake.addPool(stTokenAddress, poolWeight, minDepositAmount, withdrawLockedBlocks)
  await txAddPool.wait()
  console.log("✅ 池子添加成功，stToken: ETH (0x0), poolWeight:", poolWeight)

  // 5️⃣ 查看池子信息
  const pool = await metaNodeStake.pools(0)
  console.log("\n📊 当前池子信息:")
  console.log("   - stTokenAddress:", pool.stToken)
  console.log("   - poolWeight:", pool.poolWeights)
  console.log("   - lastRewardBlock:", pool.lastRewardBlock)
  console.log("   - stTokenAmount:", pool.stAmount)
  console.log("   - minDepositAmount:", pool.minDepositAmount)
  console.log("   - withdrawLockedBlocks:", pool.unStakeLockBolcks)
  // 🎉 完成
  console.log("\n🎉 模拟运行完成！所有流程执行成功！")
}

main()
