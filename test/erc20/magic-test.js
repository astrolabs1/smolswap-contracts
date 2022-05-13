// const { expect } = require("chai");
// const { ethers } = require("hardhat");

// describe("Magic Token", function () {

//     let MagicToken;
//     let accounts;
//     let owner;

//     beforeEach(async function () {
//         accounts = await ethers.getSigners();
//         owner = accounts[0];
//         const MagicFactory = await ethers.getContractFactory("Magic");
//         MagicToken = await MagicFactory.deploy();
//         await MagicToken.deployed();
//     });
    
//   it("Should deploy the magic token contract and set owner", async function () {
//     expect(await MagicToken.owner()).to.equal(accounts[0].address);
//   });

//   it("Total Supply at deployment should equal the token supply of the owner", async function () {
//     expect(await MagicToken.balanceOf(accounts[0].address)).to.equal(await MagicToken.totalSupply());
//   });

// });
