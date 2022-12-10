const { network } = require("hardhat")
const { developmentChains } = require("../helper-hardhat-config")

const BASE_FEE = ethers.utils.parseEther("0.25") //premium to call a price feed
const GAS_PRICE_LINK = 1e9 //link per gas

//chainlink nodes pay the gas fee to give the randomness and do external execution
// the price of requests change based on the price of gas

module.exports = async (hre) => {
    const { getNamedAccounts, deployments } = hre
    const { deploy, log } = deployments
    const { deployer } = await getNamedAccounts()
    const chainId = network.config.chainId

    if (developmentChains.includes(network.name)) {
        log("deploying mocks")
        await deploy("VRFCoordinatorV2Mock", {
            from: deployer,
            log: true,
            args: [BASE_FEE, GAS_PRICE_LINK],
            waitConfirmations: 1,
        })
        log("Mocks deployed")
    }
}

module.exports.tags = ["all", "mocks"]
