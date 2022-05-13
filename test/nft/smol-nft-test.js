// const { expect } = require("chai");
// const { ethers } = require("hardhat");

// describe("Treasure Marketplace", function () {

//     let accounts;
    
//     let owner;

//     let SimpleFakeSmolNFT;
    
//     beforeEach(async function () {
//         accounts = await ethers.getSigners();

//         owner = accounts[0];
//         const SimpleFakeSmolNFTFactory = await ethers.getContractFactory("SimpleFakeSmolNFT");
//         SimpleFakeSmolNFT = await SimpleFakeSmolNFTFactory.deploy();
//         await SimpleFakeSmolNFT.deployed();
//     });
    
//   it("Should deploy the fake smol nft contract and set owner", async function () {
//     expect(await SimpleFakeSmolNFT.owner()).to.equal(accounts[0].address);
//   });
// });
