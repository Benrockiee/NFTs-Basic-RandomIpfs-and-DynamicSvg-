//SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract BasicNft is ERC721 {
    string public constant TOKEN_URI =
        "ipfs://bafybeig37ioir76s7mg5oobetncojcm3c3hxasyd4rvid4jqhy4gkaheg4/?filename=0-PUG.json";
    uint256 private s_tokenCounter;

    constructor() ERC721("Dogie", "DOG") {
        s_tokenCounter = 0;
    }

    //To make new dogs, openzeppelin comes with a mint function
    //Also anybody who mints one, will have this same puppy above
    function mintNft() public returns (uint256) {
        //This means anytime we mint a new NFT
        _safeMint(msg.sender, s_tokenCounter);
        //We up that token counter
        s_tokenCounter = s_tokenCounter + 1;
        //Then we return the new token counter
        return s_tokenCounter;
    }

    function tokenURI(
        uint256 /*tokenId*/
    ) public pure override returns (string memory) {
        return TOKEN_URI;
    }

    function getTokenCounter() public view returns (uint256) {
        return s_tokenCounter;
    }

    //Now this token isnt gonna look like anything without the tokenUri(universal resource
    // identifier) because it tells us what this token is going to look like ..
}
