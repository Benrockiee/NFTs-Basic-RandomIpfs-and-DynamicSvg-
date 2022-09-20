const pinataSDK = require("@pinata/sdk")

const path = require("path")
const fs = require("fs")
//We pull in our .env file
require("dotenv").config()

const pinataApiKey = process.env.PINATA_API_KEY
const pinataApiSecret = process.env.PINATA_API_SECRET
const pinata = pinataSDK(pinataApiKey, pinataApiSecret)

//We pass it our images file path and have it store everything in that folder
//However to help us work with paths, we need to install the path package //yarn add --dev path
async function storeImages(imagesFilePath) {
    //this gives us the full output of the path in our folder
    const fullImagesPath = path.resolve(imagesFilePath)
    // we get those files by doing this and
    //this will read the entire directory and get our files back
    const files = fs.readdirSync(fullImagesPath)
    //we create an array for responses from pinata server
    let responses = []
    console.log("Uploading to IPFS...")
    //for each file index in files
    for (fileIndex in files) {
        //We create a stream where we stream all the data inside that images folder
        const readableStreamForFile = fs.createReadStream(`${fullImagesPath}/${files[fileIndex]}`)
        try {
            //  PinFilesToIPFS is going to return the hash of the files & we need that hash to add
            // to our meta data
            const response = await pinata.pinFileToIPFS(readableStreamForFile)
            responses.push(response)
        } catch (error) {
            console.log(error)
        }
    }
    //So we'll return the responses of those files we pushed
    return { responses, files }
}
//Referencing out Metadata Template
async function storeTokenUriMetadata(metadata) {
    try {
        const response = await pinata.pinJSONToIPFS(metadata)
        //if this works well, we say:
        return response
    } catch (error) {
        console.log(error)
    }
    return null
}
//we export storeTokenUriMetadata
module.exports = { storeImages, storeTokenUriMetadata }
