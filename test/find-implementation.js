// scripts/find-implementation.js
const { upgrades } = require("hardhat")

async function main() {
  const proxyAddress = "0xcB595Df4186287e8Dc6227b633714E5CF062599c" // 替换为你部署的代理地址

  const implAddress = await upgrades.erc1967.getImplementationAddress(proxyAddress)
  console.log("Implementation (MetaNodeStake) Address:", implAddress)
}

main()
