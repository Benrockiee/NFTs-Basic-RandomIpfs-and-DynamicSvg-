const { network, ethers } = require("hardhat")
const { developmentChains, networkConfig } = require("../helper-hardhat-config")
const { verify } = require("../utils/verify")
const { storeImages, storeTokenUriMetadata } = require("../utils/upload-to-pinata")

const FUND_AMOUNT = "1000000000000000000000" //10 Link
const imagesLocation = "./images/randomNfts/"
const metadataTemplate = {
    name: "",
    description: "",
    image: "",
    attributes: [
        {
            trait_type: "Cuteness",
            value: 100,
        },
    ],
}

let tokenUris = [
    "ipfs://QmaVkBn2tKmjbhphU7eyztbvSQU5EXDdqRyXZtRhSGgJGo",
    "ipfs://QmYQC5aGZu2PTH8XzbJrbDnvhj3gVs7ya33H9mqUNvST3d",
    "ipfs://QmZYmH5iDbD6v3U2ixoVAjioSzvWJszDzYdbeCLquGSpVm",
]

module.exports = async function ({ getNamedAccounts, deployments }) {
    const { deploy, log } = deployments
    const { deployer } = await getNamedAccounts()
    const chainId = network.config.chainId

    //get the IPFS hashes of our images
    if (process.env.UPLOAD_TO_PINATA == "true") {
        tokenUris = await handleTokenUris()
    }

    let vrfCoordinatorV2Address, subscriptionId

    if (chainId == 31337) {
        // create VRFV2 Subscription
        const vrfCoordinatorV2Mock = await ethers.getContract("VRFCoordinatorV2Mock")
        vrfCoordinatorV2Address = vrfCoordinatorV2Mock.address
        //Then we wanna create a subscription
        const tx = await vrfCoordinatorV2Mock.createSubscription()
        const txReceipt = await tx.wait(1)
        //Then We get the subscription id
        subscriptionId = txReceipt.events[0].args.subId
        // Fund the subscription
        // Our mock makes it so we don't actually have to worry about sending fund
        await vrfCoordinatorV2Mock.fundSubscription(subscriptionId, FUND_AMOUNT)
    } else {
        vrfCoordinatorV2Address = networkConfig[chainId].vrfCoordinatorV2
        subscriptionId = networkConfig[chainId].subscriptionId
    }
    log("-------------------------------------")

    const args = [
        //These are the constructor arguments:
        vrfCoordinatorV2Address,
        subscriptionId,
        networkConfig[chainId].gasLane,
        networkConfig[chainId].mintFee,
        networkConfig[chainId].callbackGasLimit,
        tokenUris,
    ]
    const randomIpfsNft = await deploy("RandomIpfsNft", {
        from: deployer,
        log: true,
        args: args,
        waitConfirmations: networkConfig.blockConfirmations || 1,
    })

    log("--------------------------------------")

    if (!developmentChains.includes(network.name) && process.env.ETHERSCAN_API_KEY) {
        log("Verifying....")
        await verify(randomIpfsNft.address, args)
    }
}
//this is gonna return an array of tokenUris for us to upload in our smart contracts
async function handleTokenUris() {
    tokenUris = []

    //We need to do two things:
    //store the image on Ipfs and
    //store the metadata in Ipfs

    //This is gonna be a list of those responses from pinata and these responses are gonna have
    //the hashes of these uploaded files. We are gonna loop through that list and uploaad each of
    //the metadatas
    const { responses: imageUploadResponses, files } = await storeImages(imagesLocation)
    for (imageUploadResponseIndex in imageUploadResponses) {
        //create metadata
        //upload metadata
        let tokenUriMetadata = { ...metadataTemplate }
        //Metadata names like pug, st bernard, or shiba inu
        tokenUriMetadata.name = files[imageUploadResponseIndex].replace(".png", "")
        tokenUriMetadata.description = `An adorable ${tokenUriMetadata.name} pup!`
        tokenUriMetadata.image = `ipfs://${imageUploadResponses[imageUploadResponseIndex].IpfsHash}`
        console.log(`Uploading ${tokenUriMetadata.name}...`)
        //store the JSON to pinata
        const metadataUploadResponse = await storeTokenUriMetadata(tokenUriMetadata)
        //Now we finally have the tokenUris that we need
        tokenUris.push(`ipfs://${metadataUploadResponse.IpfsHash}`)
    }
    console.log("Token URIs uploaded! They are:")
    console.log(tokenUris)

    return tokenUris
}

module.exports.tags = ["all", "randomIpfsNft", "main"]
