// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "hardhat/console.sol";

error AlreadyInitialized();
error NeedMoreETHSent();
error RangeOutOfBounds();
error RandomIpfsNft__TransferFailed();

contract RandomIpfsNft is ERC721URIStorage, VRFConsumerBaseV2, Ownable {
    // Types
    enum Breed {
        PUG,
        SHIBA_INU,
        ST_BERNARD
    }

    // Chainlink VRF Variables
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    uint64 private immutable i_subscriptionId;
    bytes32 private immutable i_gasLane;
    uint32 private immutable i_callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    // NFT Variables
    uint256 private immutable i_mintFee;
    uint256 private s_tokenCounter;
    uint256 internal constant MAX_CHANCE_VALUE = 100;
    string[] internal s_dogTokenUris;
    bool private s_initialized;

    // VRF Helpers
    mapping(uint256 => address) public s_requestIdToSender;

    // Events
    event NftRequested(uint256 indexed requestId, address requester);
    event NftMinted(Breed breed, address minter);

    constructor(
        address vrfCoordinatorV2,
        uint64 subscriptionId,
        bytes32 gasLane, // keyHash
        uint256 mintFee,
        uint32 callbackGasLimit,
        string[3] memory dogTokenUris
    ) VRFConsumerBaseV2(vrfCoordinatorV2) ERC721("Random IPFS NFT", "RIN") {
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_mintFee = mintFee;
        i_callbackGasLimit = callbackGasLimit;
        _initializeContract(dogTokenUris);
    }

    //Whoever calls this request function, it will be their NFT
    function requestNft() public payable returns (uint256 requestId) {
        //This means people will have to pay some fees in other to mint their Random NFTS
        if (msg.value < i_mintFee) {
            revert NeedMoreETHSent();
        }
        //Makes a chainlink request to get a random number
        requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );

        s_requestIdToSender[requestId] = msg.sender;
        emit NftRequested(requestId, msg.sender);
    }

    //It is the chainlink nodes that calls fulfillRandomWords
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        //This time, the chainlink nodes wont own the dogs, its gonna be whoever calls the requestNft
        address dogOwner = s_requestIdToSender[requestId];
        //We make a token counter for increment
        uint256 newItemId = s_tokenCounter;
        s_tokenCounter = s_tokenCounter + 1;
        uint256 moddedRng = randomWords[0] % MAX_CHANCE_VALUE;
        //During this mod, we expect the following:
        //0 to 10 = pug;
        //10 to 40 = shibainu;
        //then between 40 to 100, we get st bernard and thats how we get this random values

        Breed dogBreed = getBreedFromModdedRng(moddedRng);
        //We import openzeppelin here and then mint this NFT here
        _safeMint(dogOwner, newItemId);
        _setTokenURI(newItemId, s_dogTokenUris[uint256(dogBreed)]);
        emit NftMinted(dogBreed, dogOwner);
    }

    //This is going to represent the different chances of these different dogs
    function getChanceArray() public pure returns (uint256[3] memory) {
        return [10, 40, MAX_CHANCE_VALUE];
    }

    function _initializeContract(string[3] memory dogTokenUris) private {
        if (s_initialized) {
            revert AlreadyInitialized();
        }
        s_dogTokenUris = dogTokenUris;
        s_initialized = true;
    }

    //We make a function and return the breed of the dog and the breed of the dog is gonna be an ENUM
    function getBreedFromModdedRng(uint256 moddedRng) public pure returns (Breed) {
        uint256 cumulativeSum = 0;
        uint256[3] memory chanceArray = getChanceArray();
        for (uint256 i = 0; i < chanceArray.length; i++) {
            // Pug = 0 - 9  (10%)
            // Shiba-inu = 10 - 39  (30%)
            // St. Bernard = 40 = 99 (60%)
            if (moddedRng >= cumulativeSum && moddedRng < chanceArray[i]) {
                return Breed(i);
            }
            cumulativeSum = chanceArray[i];
        }
        revert RangeOutOfBounds();
    }

    function withdraw() public onlyOwner {
        uint256 amount = address(this).balance;
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) {
            revert RandomIpfsNft__TransferFailed();
        }
    }

    function getMintFee() public view returns (uint256) {
        return i_mintFee;
    }

    function getDogTokenUris(uint256 index) public view returns (string memory) {
        return s_dogTokenUris[index];
    }

    function getInitialized() public view returns (bool) {
        return s_initialized;
    }

    function getTokenCounter() public view returns (uint256) {
        return s_tokenCounter;
    }
}
// we don need a function for tokenURI anymore because when we call setToken URI(in our fulfillRandomWords)
//its going to set out tokenURI for us and behind the scenes, the ERC721URIstorage already has that
//function laid out for us so we already have it and we dont explicitly have to set it ourselves
