const { ethers, network } = require("hardhat")
const { parseEther } = ethers

async function main() {
  console.log("🌍 开始运行 MetaNodeStake 模拟脚本...")
  console.log("⛓️  当前网络:", network.name)

  const [deployer] = await ethers.getSigners()
  console.log("\n👋 部署者地址:", deployer.address)

  // 1️⃣ 部署 MetaNode (MockMetaNode)
  console.log("\n🔄 步骤 1: 部署 MetaNode 代币...")
  const MetaNode = await ethers.getContractFactory("MetaNodeToken")
  const metaNode = await MetaNode.deploy()
  await metaNode.waitForDeployment()
  const metaNodeAddress = await metaNode.getAddress()
  console.log("✅ MetaNode 部署成功，地址:", metaNodeAddress)

  // 2️⃣ 部署 MetaNodeStake
  console.log("\n🔄 步骤 2: 部署 MetaNodeStake 合约...")
  const MetaNodeStake = await ethers.getContractFactory("MetaNodeStake")
  const metaNodeStake = await MetaNodeStake.deploy()
  await metaNodeStake.waitForDeployment()
  const stakeAddress = await metaNodeStake.getAddress()
  console.log("✅ MetaNodeStake 部署成功，地址:", stakeAddress)

  // 3️⃣ 初始化
  console.log("\n🔄 步骤 3: 初始化 MetaNodeStake...")
  await metaNodeStake.initialize(
    metaNodeAddress,
    100, // startBlock
    100000000, // endBlock
    parseEther("3") // ethPerMetaNode
  )
  console.log("✅ 初始化完成")
}

// ✅ 主函数启动
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ 脚本执行出错:", error)
    process.exit(1)
  })
