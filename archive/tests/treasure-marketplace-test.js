const { expect } = require("chai");
const { BigNumber } = require("ethers");
const { ethers } = require("hardhat");

describe("Treasure Marketplace", function () {

    let accounts;

    let owner;

    let seller;
    let buyer;
    let buyer2;
    let buyer3;

    let feeRecipient;

    let treasureMarketplaceFee;
    let treasureMarketplaceFeeOutOfUnits;
    let treasureMarketplaceFeeRecipient;

    let listings_list = [];

    let MagicToken;
    let MagicTokenDecimals;
    let MagicTokenTotalSupply;

    let TestInputToken;
    let TestInputTokenDecimals;
    let TestInputTokenTotalSupply;

    let WETH9;

    let SimpleSmolNFT;
    let SimpleSmolNFTTotalSupply;

    let NFTERC1155;

    let TreasureMarketplace;
    let TreasureNFTOracle;

    let TreasureMarketplaceMultiBuyer;


    let UniswapV2ERC20;
    let UniswapV2Factory;
    let UniswapV2Router02;

    let UniswapV2PairFactory;


    let Magic_WETH_Pair;
    let Magic_INPUT_TOKEN_PAIR;

    let MAX_UINT256 = BigNumber.from("0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff")

    beforeEach(async function () {
        accounts = await ethers.getSigners();
        owner = accounts[0];

        seller = accounts[1];
        buyer = accounts[2];
        buyer2 = accounts[3];
        buyer3 = accounts[4];
        treasureMarketplaceFeeRecipient = accounts[5];
        treasureMarketplaceFee = 500;
        treasureMarketplaceFeeOutOfUnits = 10000;

        const MagicFactory = await ethers.getContractFactory("Magic");
        MagicToken = await MagicFactory.deploy();
        await MagicToken.deployed();
        MagicTokenDecimals = await MagicToken.decimals();
        MagicTokenTotalSupply = await MagicToken.totalSupply();

        const TestInputTokenFactory = await ethers.getContractFactory("TestInputToken");
        TestInputToken = await TestInputTokenFactory.deploy();
        await TestInputToken.deployed();
        TestInputTokenDecimals = await TestInputToken.decimals();
        TestInputTokenTotalSupply = await TestInputToken.totalSupply();

        const SimpleFakeSmolNFTFactory = await ethers.getContractFactory("SimpleFakeSmolNFT");
        SimpleSmolNFT = await SimpleFakeSmolNFTFactory.deploy();
        await SimpleSmolNFT.deployed();

        const NFTERC1155Factory = await ethers.getContractFactory("NFTERC1155");
        NFTERC1155 = await NFTERC1155Factory.deploy();
        await NFTERC1155.deployed();

        const TreasureNFTOracleFactory = await ethers.getContractFactory("TreasureNFTOracle");
        TreasureNFTOracle = await TreasureNFTOracleFactory.deploy();
        await TreasureNFTOracle.deployed();

        const TreasureMarketplaceFactory = await ethers.getContractFactory("TreasureMarketplace");
        TreasureMarketplace = await TreasureMarketplaceFactory.deploy(treasureMarketplaceFee, treasureMarketplaceFeeRecipient.address, TreasureNFTOracle.address, MagicToken.address);
        await TreasureMarketplace.deployed();

        await TreasureNFTOracle.transferOwnership(TreasureMarketplace.address);

    });


    it("Should deploy the Treasure Marketplace and Oracle contracts and set owner", async function () {
        expect(await TreasureMarketplace.owner()).to.equal(accounts[0].address);
        expect(await TreasureNFTOracle.owner()).to.equal(TreasureMarketplace.address);
    });

    it("The oracle of the marketplace should be the Treasure NFT Oracle address", async function () {
        expect(await TreasureMarketplace.oracle()).to.equal(TreasureNFTOracle.address);
    });

    it("Payment Token should equal to the Magic Token address", async function () {
        expect(await TreasureMarketplace.paymentToken()).to.equal(MagicToken.address);
    });


    describe("Treasure Marketplace Swaps", function () {
        beforeEach(async function () {

            await TreasureMarketplace.addToWhitelist(SimpleSmolNFT.address);

            for (let i = 0; i < 5; i++) {
                await SimpleSmolNFT.safeMint(seller.address);
            }

            await SimpleSmolNFT.connect(seller).setApprovalForAll(TreasureMarketplace.address, true);

            await MagicToken.transfer(buyer.address, BigNumber.from("20000000000000000000"));
            await MagicToken.transfer(buyer2.address, BigNumber.from("20000000000000000000"));
            await MagicToken.transfer(buyer3.address, BigNumber.from("20000000000000000000"));

            MagicToken.connect(buyer).approve(TreasureMarketplace.address, MagicTokenTotalSupply);
            MagicToken.connect(buyer2).approve(TreasureMarketplace.address, MagicTokenTotalSupply);
            MagicToken.connect(buyer3).approve(TreasureMarketplace.address, MagicTokenTotalSupply);

            let res = await SimpleSmolNFT.connect(seller).balanceOf(seller.address);

            for (let i = 0; i < 5; i++) {
                listings_list.push({
                    seller: seller,
                    token_id: i,
                    amount: 1,
                    price: 100000000000000,
                    expiration_time: 2000000000000,
                });
                await TreasureMarketplace.connect(seller).createListing(SimpleSmolNFT.address, listings_list[i].token_id, listings_list[i].amount, listings_list[i].price, listings_list[i].expiration_time);
            }
        });


        it("Single Buy", async function () {

            const buyer1 = buyer;

            const buyerMagicTokenBalanceBefore = await MagicToken.balanceOf(buyer1.address);
            const buyerNFTBalanceBefore = await SimpleSmolNFT.balanceOf(buyer1.address);

            const NFTprice = listings_list[0].price;
            await TreasureMarketplace.connect(buyer1).buyItem(SimpleSmolNFT.address, 0, seller.address, 1);

            expect(await SimpleSmolNFT.balanceOf(buyer1.address)).to.equal(buyerNFTBalanceBefore.add(1));
            expect((await SimpleSmolNFT.ownerOf(listings_list[0].token_id)).toLowerCase()).to.equal(buyer1.address.toLowerCase());
            expect(await MagicToken.balanceOf(buyer1.address)).to.equal(buyerMagicTokenBalanceBefore.sub(NFTprice));
        });


        describe("Multi Buy", function () {
            beforeEach(async function () {
                const UniswapV2ERC20Factory = await ethers.getContractFactory("UniswapV2ERC20");
                const UniswapV2FactoryFactory = await ethers.getContractFactory("UniswapV2Factory");
                const WETH9Factory = await ethers.getContractFactory("WETH9");
                const UniswapV2Router02Factory = await ethers.getContractFactory("UniswapV2Router02");

                UniswapV2PairFactory = await ethers.getContractFactory("UniswapV2Pair");

                UniswapV2ERC20 = await UniswapV2ERC20Factory.deploy();
                UniswapV2Factory = await UniswapV2FactoryFactory.deploy(owner.address);
                WETH9 = await WETH9Factory.deploy();
                UniswapV2Router02 = await UniswapV2Router02Factory.deploy(UniswapV2Factory.address, WETH9.address);

                await UniswapV2ERC20.deployed();
                await UniswapV2Factory.deployed();
                await WETH9.deployed();
                await UniswapV2Router02.deployed();

                const TreasureMarketplaceMultiBuyerFactory = await ethers.getContractFactory("TreasureMarketplaceMultiBuyer");

                console.log("treasuremarketplace:", TreasureMarketplace.address);
                console.log("MagicToken:", MagicToken.address);

                TreasureMarketplaceMultiBuyer = await TreasureMarketplaceMultiBuyerFactory.deploy(TreasureMarketplace.address, MagicToken.address, 0, owner.address, [UniswapV2Router02.address, UniswapV2Router02.address]);
                await TreasureMarketplaceMultiBuyer.deployed();

            });

            it("Marketplace contract address should be set correctly", async function () {
                expect(await TreasureMarketplaceMultiBuyer.marketplace()).to.equal(TreasureMarketplace.address);
            });

            it("Fees should be set correctly", async function () {
                expect(await TreasureMarketplaceMultiBuyer.fees()).to.equal(0);
            });

            it("Fee recipient should be set correctly", async function () {
                expect(await TreasureMarketplaceMultiBuyer.feeRecipient()).to.equal(accounts[0].address);
            });

            it("Default payment token should be set correctly", async function () {
                expect(await TreasureMarketplaceMultiBuyer.defaultPaymentToken()).to.equal(MagicToken.address);
            });

            it("Price Update", async function () {
                const buyer1 = (await ethers.getSigners())[0];

                const buyerMagicTokenBalanceBefore = await MagicToken.balanceOf(buyer1.address);
                const sellerMagicTokenBalanceBefore = await MagicToken.balanceOf(seller.address);

                await MagicToken.approve(TreasureMarketplace.address, buyerMagicTokenBalanceBefore);

                const newLargePrice = BigNumber.from("1111111111111111111111111111111111111111111111111");
                await TreasureMarketplace.connect(seller).updateListing(SimpleSmolNFT.address, 0, listings_list[0].amount, newLargePrice, listings_list[0].expiration_time);
                await TreasureMarketplace.connect(buyer1).buyItem(SimpleSmolNFT.address, 0, seller.address, 1);

                expect(await SimpleSmolNFT.balanceOf(buyer1.address)).to.equal(1);
                expect(await MagicToken.balanceOf(buyer1.address)).to.equal(buyerMagicTokenBalanceBefore.sub(newLargePrice));
                expect(await MagicToken.balanceOf(seller.address)).to.equal(sellerMagicTokenBalanceBefore.add(newLargePrice).sub(newLargePrice.mul(BigNumber.from(treasureMarketplaceFee)).div(BigNumber.from(treasureMarketplaceFeeOutOfUnits))));
            })

            it.only("Should buy multiple ERC721 All Try Catch and succeed", async function () {

                const buyer1 = (await ethers.getSigners())[0];

                const buyerMagicTokenBalanceBefore = await MagicToken.balanceOf(buyer1.address);
                const sellerMagicTokenBalanceBefore = await MagicToken.balanceOf(seller.address);

                let contractAddresses = [SimpleSmolNFT.address, SimpleSmolNFT.address, SimpleSmolNFT.address];

                let tokenIds = [listings_list[0].token_id, listings_list[1].token_id, listings_list[2].token_id];
                let amounts = [1, 1, 1];
                let prices = [listings_list[0].price, listings_list[1].price, listings_list[2].price];

                let owners = [listings_list[0].seller.address, listings_list[1].seller.address, listings_list[2].seller.address];

                let totalPrice = listings_list[0].price + listings_list[1].price + listings_list[2].price;

                await MagicToken.connect(buyer1).approve(TreasureMarketplaceMultiBuyer.address, BigNumber.from("115792089237316195423570985008687907853269984665640564039457584007913129639935"));

                await TreasureMarketplaceMultiBuyer.connect(buyer1).multiBuyERC721UsingPaymentTokenWithTryCatch(contractAddresses, tokenIds, owners, amounts, prices);
                expect(await SimpleSmolNFT.balanceOf(buyer1.address)).to.equal(3);
                expect((await SimpleSmolNFT.ownerOf(listings_list[0].token_id)).toLowerCase()).to.equal(buyer1.address.toLowerCase());
                expect((await SimpleSmolNFT.ownerOf(listings_list[1].token_id)).toLowerCase()).to.equal(buyer1.address.toLowerCase());
                expect((await SimpleSmolNFT.ownerOf(listings_list[2].token_id)).toLowerCase()).to.equal(buyer1.address.toLowerCase());

                const totalSpent = listings_list[0].price + listings_list[1].price + listings_list[2].price;
                expect(await MagicToken.balanceOf(buyer1.address)).to.equal(buyerMagicTokenBalanceBefore.sub(totalSpent));
                expect(await MagicToken.balanceOf(seller.address)).to.equal((sellerMagicTokenBalanceBefore.add(totalSpent)).sub((BigNumber.from(totalSpent)).mul(BigNumber.from(treasureMarketplaceFee)).div(BigNumber.from(treasureMarketplaceFeeOutOfUnits))));
                expect(await MagicToken.balanceOf(TreasureMarketplaceMultiBuyer.address)).to.equal(0);
            });

            it("Price lowered but should buy multiple ERC721 All Try Catch and succeed", async function () {

                let discount = 10;

                const buyer1 = (await ethers.getSigners())[0];

                const buyerMagicTokenBalanceBefore = await MagicToken.balanceOf(buyer1.address);
                const sellerMagicTokenBalanceBefore = await MagicToken.balanceOf(seller.address);

                let contractAddresses = [SimpleSmolNFT.address, SimpleSmolNFT.address, SimpleSmolNFT.address];

                let tokenIds = [listings_list[0].token_id, listings_list[1].token_id, listings_list[2].token_id];
                let amounts = [1, 1, 1];
                let prices = [listings_list[0].price, listings_list[1].price, listings_list[2].price];

                let owners = [listings_list[0].seller.address, listings_list[1].seller.address, listings_list[2].seller.address];

                let totalPrice = listings_list[0].price + listings_list[1].price + listings_list[2].price;

                await TreasureMarketplace.connect(seller).updateListing(SimpleSmolNFT.address, listings_list[0].token_id, listings_list[0].amount, listings_list[0].price - discount, listings_list[0].expiration_time);

                await MagicToken.connect(buyer1).approve(TreasureMarketplaceMultiBuyer.address, BigNumber.from("115792089237316195423570985008687907853269984665640564039457584007913129639935"));

                await TreasureMarketplaceMultiBuyer.connect(buyer1).multiBuyERC721UsingPaymentTokenWithTryCatch(contractAddresses, tokenIds, owners, amounts, prices);
                expect(await SimpleSmolNFT.balanceOf(buyer1.address)).to.equal(3);
                expect((await SimpleSmolNFT.ownerOf(listings_list[0].token_id)).toLowerCase()).to.equal(buyer1.address.toLowerCase());
                expect((await SimpleSmolNFT.ownerOf(listings_list[1].token_id)).toLowerCase()).to.equal(buyer1.address.toLowerCase());
                expect((await SimpleSmolNFT.ownerOf(listings_list[2].token_id)).toLowerCase()).to.equal(buyer1.address.toLowerCase());

                const totalSpent = listings_list[0].price - discount + listings_list[1].price + listings_list[2].price;
                expect(await MagicToken.balanceOf(buyer1.address)).to.equal(buyerMagicTokenBalanceBefore.sub(totalSpent));
                expect(await MagicToken.balanceOf(seller.address)).to.equal((sellerMagicTokenBalanceBefore.add(totalSpent)).sub((BigNumber.from(totalSpent)).mul(BigNumber.from(treasureMarketplaceFee)).div(BigNumber.from(treasureMarketplaceFeeOutOfUnits))));
                expect(await MagicToken.balanceOf(TreasureMarketplaceMultiBuyer.address)).to.equal(0);
            });

            it("Should try to buy multiple ERC721 All Try Catch and succeed but fail if price is set higher.", async function () {

                const buyer1 = (await ethers.getSigners())[0];

                const buyerMagicTokenBalanceBefore = await MagicToken.balanceOf(buyer1.address);
                const sellerMagicTokenBalanceBefore = await MagicToken.balanceOf(seller.address);

                let contractAddresses = [SimpleSmolNFT.address, SimpleSmolNFT.address, SimpleSmolNFT.address];

                let tokenIds = [listings_list[0].token_id, listings_list[1].token_id, listings_list[2].token_id];
                let amounts = [1, 1, 1];
                let prices = [listings_list[0].price, listings_list[1].price, listings_list[2].price];

                let owners = [listings_list[0].seller.address, listings_list[1].seller.address, listings_list[2].seller.address];

                let totalPrice = listings_list[0].price + listings_list[1].price + listings_list[2].price;

                await TreasureMarketplace.connect(seller).updateListing(SimpleSmolNFT.address, listings_list[0].token_id, listings_list[0].amount, listings_list[0].price + 1, listings_list[0].expiration_time);

                await MagicToken.connect(buyer1).approve(TreasureMarketplaceMultiBuyer.address, BigNumber.from("115792089237316195423570985008687907853269984665640564039457584007913129639935"));

                await TreasureMarketplaceMultiBuyer.connect(buyer1).multiBuyERC721UsingPaymentTokenWithTryCatch(contractAddresses, tokenIds, owners, amounts, prices);
                expect(await SimpleSmolNFT.balanceOf(buyer1.address)).to.equal(2);
                expect((await SimpleSmolNFT.ownerOf(listings_list[0].token_id)).toLowerCase()).to.equal(seller.address.toLowerCase());
                expect((await SimpleSmolNFT.ownerOf(listings_list[1].token_id)).toLowerCase()).to.equal(buyer1.address.toLowerCase());
                expect((await SimpleSmolNFT.ownerOf(listings_list[2].token_id)).toLowerCase()).to.equal(buyer1.address.toLowerCase());

                const totalSpent = listings_list[1].price + listings_list[2].price;
                expect(await MagicToken.balanceOf(buyer1.address)).to.equal(buyerMagicTokenBalanceBefore.sub(totalSpent));
                expect(await MagicToken.balanceOf(seller.address)).to.equal((sellerMagicTokenBalanceBefore.add(totalSpent)).sub((BigNumber.from(totalSpent)).mul(BigNumber.from(treasureMarketplaceFee)).div(BigNumber.from(treasureMarketplaceFeeOutOfUnits))));
                expect(await MagicToken.balanceOf(TreasureMarketplaceMultiBuyer.address)).to.equal(0);
            });

            it("Should try to buy multiple ERC721 but only succeed the 1st.", async function () {

                const buyer1 = (await ethers.getSigners())[0];

                const buyerMagicTokenBalanceBefore = await MagicToken.balanceOf(buyer1.address);
                const sellerMagicTokenBalanceBefore = await MagicToken.balanceOf(seller.address);

                let contractAddresses = [SimpleSmolNFT.address, SimpleSmolNFT.address, SimpleSmolNFT.address];

                let tokenIds = [listings_list[0].token_id, 543543, listings_list[2].token_id];
                let amounts = [1, 1, 1];
                let prices = [listings_list[0].price, listings_list[1].price, 10];

                let owners = [listings_list[0].seller.address, listings_list[1].seller.address, listings_list[2].seller.address];

                let totalPrice = listings_list[0].price + listings_list[1].price + listings_list[2].price;

                await MagicToken.connect(buyer1).approve(TreasureMarketplaceMultiBuyer.address, BigNumber.from("115792089237316195423570985008687907853269984665640564039457584007913129639935"));

                await TreasureMarketplaceMultiBuyer.multiBuyERC721UsingPaymentTokenWithTryCatch(contractAddresses, tokenIds, owners, amounts, prices);
                expect(await SimpleSmolNFT.balanceOf(buyer1.address)).to.equal(1);
                expect((await SimpleSmolNFT.ownerOf(listings_list[0].token_id)).toLowerCase()).to.equal(buyer1.address.toLowerCase());
                expect((await SimpleSmolNFT.ownerOf(listings_list[1].token_id)).toLowerCase()).to.equal(seller.address.toLowerCase());
                expect((await SimpleSmolNFT.ownerOf(listings_list[2].token_id)).toLowerCase()).to.equal(seller.address.toLowerCase());

                const totalSpent = listings_list[0].price;
                expect(await MagicToken.balanceOf(buyer1.address)).to.equal(buyerMagicTokenBalanceBefore.sub(totalSpent));
                expect(await MagicToken.balanceOf(seller.address)).to.equal((sellerMagicTokenBalanceBefore.add(totalSpent)).sub((BigNumber.from(totalSpent)).mul(BigNumber.from(treasureMarketplaceFee)).div(BigNumber.from(treasureMarketplaceFeeOutOfUnits))));
                expect(await MagicToken.balanceOf(TreasureMarketplaceMultiBuyer.address)).to.equal(0);
            });

            it("Should try to buy 3 ERC721 but fail one only because got frontran.", async function () {

                const buyer1 = (await ethers.getSigners())[0];

                const sellerMagicTokenBalanceBefore = await MagicToken.balanceOf(seller.address);
                const buyerMagicTokenBalanceBefore = await MagicToken.balanceOf(buyer1.address);
                const buyer2MagicTokenBalanceBefore = await MagicToken.balanceOf(buyer2.address);

                let contractAddresses = [SimpleSmolNFT.address, SimpleSmolNFT.address, SimpleSmolNFT.address];

                let amounts = [1, 1, 1];
                let prices = [listings_list[0].price, listings_list[1].price, listings_list[2].price];

                let owners = [listings_list[0].seller.address, listings_list[1].seller.address, listings_list[2].seller.address];

                let totalPrice = listings_list[0].price + listings_list[1].price + listings_list[2].price;

                let tokenIds = [listings_list[0].token_id, listings_list[1].token_id, listings_list[2].token_id];

                await MagicToken.connect(buyer2).approve(TreasureMarketplace.address, buyerMagicTokenBalanceBefore);

                await TreasureMarketplace.connect(buyer2).buyItem(SimpleSmolNFT.address, listings_list[0].token_id, listings_list[0].seller.address, amounts[0]);

                await MagicToken.connect(buyer1).approve(TreasureMarketplaceMultiBuyer.address, BigNumber.from("115792089237316195423570985008687907853269984665640564039457584007913129639935"));

                await TreasureMarketplaceMultiBuyer.connect(buyer1).multiBuyERC721UsingPaymentTokenWithTryCatch(contractAddresses, tokenIds, owners, amounts, prices);
                expect(await SimpleSmolNFT.balanceOf(buyer1.address)).to.equal(2);
                expect((await SimpleSmolNFT.ownerOf(listings_list[0].token_id)).toLowerCase()).to.equal(buyer2.address.toLowerCase());
                expect((await SimpleSmolNFT.ownerOf(listings_list[1].token_id)).toLowerCase()).to.equal(buyer1.address.toLowerCase());
                expect((await SimpleSmolNFT.ownerOf(listings_list[2].token_id)).toLowerCase()).to.equal(buyer1.address.toLowerCase());

                const totalSpentBuyer1 = listings_list[1].price + listings_list[2].price;
                const totalSpentBuyer2 = listings_list[0].price;

                expect(await MagicToken.balanceOf(buyer1.address)).to.equal(buyerMagicTokenBalanceBefore.sub(totalSpentBuyer1));
                expect(await MagicToken.balanceOf(buyer2.address)).to.equal(buyer2MagicTokenBalanceBefore.sub(totalSpentBuyer2));
                expect(await MagicToken.balanceOf(seller.address)).to.equal((sellerMagicTokenBalanceBefore.add(totalSpentBuyer1 + totalSpentBuyer2)).sub((BigNumber.from(totalSpentBuyer1 + totalSpentBuyer2)).mul(BigNumber.from(treasureMarketplaceFee)).div(BigNumber.from(treasureMarketplaceFeeOutOfUnits))));
                expect(await MagicToken.balanceOf(TreasureMarketplaceMultiBuyer.address)).to.equal(0);
            });

            it("Should try to buy multiple ERC721 using Try Catch but All failed.", async function () {

                const buyer1 = (await ethers.getSigners())[0];

                const buyerMagicTokenBalanceBefore = await MagicToken.balanceOf(buyer1.address);
                const sellerMagicTokenBalanceBefore = await MagicToken.balanceOf(seller.address);

                let contractAddresses = [SimpleSmolNFT.address, SimpleSmolNFT.address, SimpleSmolNFT.address];

                let tokenIds = [543543, 654654, 87687];
                let amounts = [1, 1, 1];
                let prices = [listings_list[0].price, listings_list[1].price, listings_list[2].price];

                let owners = [listings_list[0].seller.address, listings_list[1].seller.address, listings_list[2].seller.address];

                let totalPrice = listings_list[0].price + listings_list[1].price + listings_list[2].price;

                await MagicToken.connect(buyer1).approve(TreasureMarketplaceMultiBuyer.address, BigNumber.from("115792089237316195423570985008687907853269984665640564039457584007913129639935"));

                expect(TreasureMarketplaceMultiBuyer.connect(buyer1).multiBuyERC721UsingPaymentTokenWithTryCatch(contractAddresses, tokenIds, owners, amounts, prices)).to.be.revertedWith("All tokens failed to be bought!");
                expect(await SimpleSmolNFT.balanceOf(buyer1.address)).to.equal(0);
                expect((await SimpleSmolNFT.ownerOf(listings_list[0].token_id)).toLowerCase()).to.equal(seller.address.toLowerCase());
                expect((await SimpleSmolNFT.ownerOf(listings_list[1].token_id)).toLowerCase()).to.equal(seller.address.toLowerCase());
                expect((await SimpleSmolNFT.ownerOf(listings_list[2].token_id)).toLowerCase()).to.equal(seller.address.toLowerCase());

                expect(await MagicToken.balanceOf(buyer1.address)).to.equal(buyerMagicTokenBalanceBefore);
                expect(await MagicToken.balanceOf(seller.address)).to.equal(sellerMagicTokenBalanceBefore);
                expect(await MagicToken.balanceOf(TreasureMarketplaceMultiBuyer.address)).to.equal(0);
            });

            it("Should buy multiple ERC721 All Atomic and succeed.", async function () {

                const buyer1 = (await ethers.getSigners())[0];

                const buyerMagicTokenBalanceBefore = await MagicToken.balanceOf(buyer1.address);
                const sellerMagicTokenBalanceBefore = await MagicToken.balanceOf(seller.address);

                let contractAddresses = [SimpleSmolNFT.address, SimpleSmolNFT.address, SimpleSmolNFT.address];

                let tokenIds = [listings_list[0].token_id, listings_list[1].token_id, listings_list[2].token_id];
                let amounts = [1, 1, 1];
                let prices = [listings_list[0].price, listings_list[1].price, listings_list[2].price];

                let owners = [listings_list[0].seller.address, listings_list[1].seller.address, listings_list[2].seller.address];

                let totalPrice = listings_list[0].price + listings_list[1].price + listings_list[2].price;

                await MagicToken.connect(buyer1).approve(TreasureMarketplaceMultiBuyer.address, BigNumber.from("115792089237316195423570985008687907853269984665640564039457584007913129639935"));

                await TreasureMarketplaceMultiBuyer.connect(buyer1).multiBuyERC721UsingPaymentTokenAllAtomic(contractAddresses, tokenIds, owners, amounts, prices);
                expect(await SimpleSmolNFT.balanceOf(buyer1.address)).to.equal(3);
                expect((await SimpleSmolNFT.ownerOf(listings_list[0].token_id)).toLowerCase()).to.equal(buyer1.address.toLowerCase());
                expect((await SimpleSmolNFT.ownerOf(listings_list[1].token_id)).toLowerCase()).to.equal(buyer1.address.toLowerCase());
                expect((await SimpleSmolNFT.ownerOf(listings_list[2].token_id)).toLowerCase()).to.equal(buyer1.address.toLowerCase());

                const totalSpent = listings_list[0].price + listings_list[1].price + listings_list[2].price;
                expect(await MagicToken.balanceOf(buyer1.address)).to.equal(buyerMagicTokenBalanceBefore.sub(totalSpent));
                expect(await MagicToken.balanceOf(seller.address)).to.equal((sellerMagicTokenBalanceBefore.add(totalSpent)).sub((BigNumber.from(totalSpent)).mul(BigNumber.from(treasureMarketplaceFee)).div(BigNumber.from(treasureMarketplaceFeeOutOfUnits))));
                expect(await MagicToken.balanceOf(TreasureMarketplaceMultiBuyer.address)).to.equal(0);
            });


            it("Should buy multiple ERC721 All Atomic and fail and revert.", async function () {

                const buyer1 = (await ethers.getSigners())[0];

                const buyerMagicTokenBalanceBefore = await MagicToken.balanceOf(buyer1.address);
                const sellerMagicTokenBalanceBefore = await MagicToken.balanceOf(seller.address);

                let contractAddresses = [SimpleSmolNFT.address, SimpleSmolNFT.address, SimpleSmolNFT.address];

                let tokenIds = [543543, 654654, 87687];
                let amounts = [1, 1, 1];
                let prices = [listings_list[0].price, listings_list[1].price, listings_list[2].price];

                let owners = [listings_list[0].seller.address, listings_list[1].seller.address, listings_list[2].seller.address];

                let totalPrice = listings_list[0].price + listings_list[1].price + listings_list[2].price;

                await MagicToken.connect(buyer1).approve(TreasureMarketplaceMultiBuyer.address, BigNumber.from("115792089237316195423570985008687907853269984665640564039457584007913129639935"));

                await expect(TreasureMarketplaceMultiBuyer.connect(buyer1).multiBuyERC721UsingPaymentTokenAllAtomic(contractAddresses, tokenIds, owners, amounts, prices)).to.be.revertedWith("not listed item");
                expect(await SimpleSmolNFT.balanceOf(buyer1.address)).to.equal(0);
                expect((await SimpleSmolNFT.ownerOf(listings_list[0].token_id)).toLowerCase()).to.equal(seller.address.toLowerCase());
                expect((await SimpleSmolNFT.ownerOf(listings_list[1].token_id)).toLowerCase()).to.equal(seller.address.toLowerCase());
                expect((await SimpleSmolNFT.ownerOf(listings_list[2].token_id)).toLowerCase()).to.equal(seller.address.toLowerCase());

                expect(await MagicToken.balanceOf(buyer1.address)).to.equal(buyerMagicTokenBalanceBefore);
                expect(await MagicToken.balanceOf(seller.address)).to.equal(sellerMagicTokenBalanceBefore);
                expect(await MagicToken.balanceOf(TreasureMarketplaceMultiBuyer.address)).to.equal(0);
            });

            it("Should try buy multiple ERC721 All Atomic but fail and revert since price is set higher.", async function () {

                const buyer1 = (await ethers.getSigners())[0];

                const buyerMagicTokenBalanceBefore = await MagicToken.balanceOf(buyer1.address);
                const sellerMagicTokenBalanceBefore = await MagicToken.balanceOf(seller.address);

                let contractAddresses = [SimpleSmolNFT.address, SimpleSmolNFT.address, SimpleSmolNFT.address];

                let tokenIds = [listings_list[0].token_id, listings_list[1].token_id, listings_list[2].token_id];
                let amounts = [1, 1, 1];
                let prices = [listings_list[0].price, listings_list[1].price, listings_list[2].price];

                let owners = [listings_list[0].seller.address, listings_list[1].seller.address, listings_list[2].seller.address];

                let totalPrice = listings_list[0].price + listings_list[1].price + listings_list[2].price;

                await TreasureMarketplace.connect(seller).updateListing(SimpleSmolNFT.address, listings_list[0].token_id, listings_list[0].amount, listings_list[0].price + 1, listings_list[0].expiration_time);

                await MagicToken.connect(buyer1).approve(TreasureMarketplaceMultiBuyer.address, BigNumber.from("115792089237316195423570985008687907853269984665640564039457584007913129639935"));

                await expect(TreasureMarketplaceMultiBuyer.connect(buyer1).multiBuyERC721UsingPaymentTokenAllAtomic(contractAddresses, tokenIds, owners, amounts, prices)).to.be.revertedWith("pricePerItem too high! Reverting...");
                expect(await SimpleSmolNFT.balanceOf(buyer1.address)).to.equal(0);
                expect((await SimpleSmolNFT.ownerOf(listings_list[0].token_id)).toLowerCase()).to.equal(seller.address.toLowerCase());
                expect((await SimpleSmolNFT.ownerOf(listings_list[1].token_id)).toLowerCase()).to.equal(seller.address.toLowerCase());
                expect((await SimpleSmolNFT.ownerOf(listings_list[2].token_id)).toLowerCase()).to.equal(seller.address.toLowerCase());

                expect(await MagicToken.balanceOf(buyer1.address)).to.equal(buyerMagicTokenBalanceBefore);
                expect(await MagicToken.balanceOf(seller.address)).to.equal(sellerMagicTokenBalanceBefore);
                expect(await MagicToken.balanceOf(TreasureMarketplaceMultiBuyer.address)).to.equal(0);
            });


            it("Should try buy multiple ERC721 All Atomic even though price updated to lower.", async function () {

                const discount = 10;

                const buyer1 = (await ethers.getSigners())[0];

                const buyerMagicTokenBalanceBefore = await MagicToken.balanceOf(buyer1.address);
                const sellerMagicTokenBalanceBefore = await MagicToken.balanceOf(seller.address);

                let contractAddresses = [SimpleSmolNFT.address, SimpleSmolNFT.address, SimpleSmolNFT.address];

                let tokenIds = [listings_list[0].token_id, listings_list[1].token_id, listings_list[2].token_id];
                let amounts = [1, 1, 1];
                let prices = [listings_list[0].price, listings_list[1].price, listings_list[2].price];

                let owners = [listings_list[0].seller.address, listings_list[1].seller.address, listings_list[2].seller.address];

                let totalPrice = listings_list[0].price + listings_list[1].price + listings_list[2].price;

                await TreasureMarketplace.connect(seller).updateListing(SimpleSmolNFT.address, listings_list[0].token_id, listings_list[0].amount, listings_list[0].price - discount, listings_list[0].expiration_time);

                await MagicToken.connect(buyer1).approve(TreasureMarketplaceMultiBuyer.address, BigNumber.from("115792089237316195423570985008687907853269984665640564039457584007913129639935"));

                await TreasureMarketplaceMultiBuyer.connect(buyer1).multiBuyERC721UsingPaymentTokenAllAtomic(contractAddresses, tokenIds, owners, amounts, prices);
                expect(await SimpleSmolNFT.balanceOf(buyer1.address)).to.equal(3);
                expect((await SimpleSmolNFT.ownerOf(listings_list[0].token_id)).toLowerCase()).to.equal(buyer1.address.toLowerCase());
                expect((await SimpleSmolNFT.ownerOf(listings_list[1].token_id)).toLowerCase()).to.equal(buyer1.address.toLowerCase());
                expect((await SimpleSmolNFT.ownerOf(listings_list[2].token_id)).toLowerCase()).to.equal(buyer1.address.toLowerCase());

                const totalSpent = listings_list[0].price + listings_list[1].price + listings_list[2].price;
                expect(await MagicToken.balanceOf(buyer1.address)).to.equal(buyerMagicTokenBalanceBefore.sub(totalSpent - discount));
                expect(await MagicToken.balanceOf(seller.address)).to.equal((sellerMagicTokenBalanceBefore.add(totalSpent - discount)).sub((BigNumber.from(totalSpent - discount)).mul(BigNumber.from(treasureMarketplaceFee)).div(BigNumber.from(treasureMarketplaceFeeOutOfUnits))));
                expect(await MagicToken.balanceOf(TreasureMarketplaceMultiBuyer.address)).to.equal(0);
            });
        });


        describe("Multi Swaps to Assets", function () {
            beforeEach(async function () {
                const UniswapV2ERC20Factory = await ethers.getContractFactory("UniswapV2ERC20");
                const UniswapV2FactoryFactory = await ethers.getContractFactory("UniswapV2Factory");
                const WETH9Factory = await ethers.getContractFactory("WETH9");
                const UniswapV2Router02Factory = await ethers.getContractFactory("UniswapV2Router02");
                const SwapFactory = await ethers.getContractFactory("Swap");

                UniswapV2PairFactory = await ethers.getContractFactory("UniswapV2Pair");

                UniswapV2ERC20 = await UniswapV2ERC20Factory.deploy();
                UniswapV2Factory = await UniswapV2FactoryFactory.deploy(owner.address);
                WETH9 = await WETH9Factory.deploy();
                UniswapV2Router02 = await UniswapV2Router02Factory.deploy(UniswapV2Factory.address, WETH9.address);
                Swap = await SwapFactory.deploy(Magic.address, [UniswapV2Router02.address, UniswapV2Router02.address]);

                const UniswapV2ERC20Address = await UniswapV2ERC20.deployed();
                const UniswapV2FactoryAddress = await UniswapV2Factory.deployed();
                const WETH9Address = await WETH9.deployed();
                const UniswapV2Router02Address = await UniswapV2Router02.deployed();
                const SwapAddress = await Swap.deployed();

                let amountETH = ethers.utils.parseEther("0.01");
                let amountMinETH = ethers.utils.parseEther("0.009");

                let amountMagic = ethers.utils.parseEther("1000000000000");
                let amountMinMagic = ethers.utils.parseEther("90000000000");

                await Magic.approve(UniswapV2Router02.address, MAX_UINT256);
                await TestInputToken.approve(UniswapV2Router02.address, MAX_UINT256);

                let createPair = await UniswapV2Factory.createPair(Magic.address, WETH9.address);
                let createPair2 = await UniswapV2Factory.createPair(Magic.address, TestInputToken.address);

                Magic_WETH_Pair = await UniswapV2PairFactory.attach(await UniswapV2Factory.allPairs(0));
                Magic_INPUT_TOKEN_PAIR = await UniswapV2PairFactory.attach(await UniswapV2Factory.allPairs(1));
                let res = await UniswapV2Router02.addLiquidityETH(Magic.address, amountMagic, amountMinMagic, amountMinETH, owner.address, getTimestamp(), { value: amountETH });
                let res2 = await UniswapV2Router02.addLiquidity(TestInputToken.address, Magic.address, amountMagic, amountMagic, amountMinMagic, amountMinMagic, owner.address, getTimestamp());

            });


            it("should swap ETH for Magic", async function () {

            });
        })

        // describe("Multi Buy ERC721 Using Payment Token with fees", function () {
        //     beforeEach(async function () {
        //         const TreasureMarketplaceMultiBuyerFactory = await ethers.getContractFactory("TreasureMarketplaceMultiBuyer");
        //         TreasureMarketplaceMultiBuyer = await TreasureMarketplaceMultiBuyerFactory.deploy(TreasureMarketplace.address);
        //         await TreasureMarketplaceMultiBuyer.deployed();

        //         feeRecipient = accounts[9];
        //         // await TreasureMarketplaceMultiBuyer.setFees(0);
        //         await TreasureMarketplaceMultiBuyer.setFeeRecipient(feeRecipient.address);
        //         await TreasureMarketplaceMultiBuyer.setDefaultPaymentToken(MagicToken.address);

        //         await TreasureMarketplaceMultiBuyer.approveTokensToTreasureMarketplace();

        //     });

        //     it("Should buy multiple ERC721 All Try Catch and succeed and pay fees.", async function () {

        //         const buyer1 = (await ethers.getSigners())[0];

        //         const buyerMagicTokenBalanceBefore = await MagicToken.balanceOf(buyer1.address);
        //         const sellerMagicTokenBalanceBefore = await MagicToken.balanceOf(seller.address);

        //         let contractAddresses = [SimpleSmolNFT.address, SimpleSmolNFT.address, SimpleSmolNFT.address];

        //         let tokenIds = [listings_list[0].token_id, listings_list[1].token_id, listings_list[2].token_id];
        //         let amounts = [1, 1, 1];
        //         let prices = [listings_list[0].price, listings_list[1].price, listings_list[2].price];

        //         let owners = [listings_list[0].seller.address, listings_list[1].seller.address, listings_list[2].seller.address];

        //         await MagicToken.connect(buyer1).approve(TreasureMarketplaceMultiBuyer.address, BigNumber.from("115792089237316195423570985008687907853269984665640564039457584007913129639935"));

        //         await TreasureMarketplaceMultiBuyer.connect(buyer1).multiBuyERC721UsingPaymentTokenWithTryCatch(contractAddresses, tokenIds, owners, amounts, prices);
        //         expect(await SimpleSmolNFT.balanceOf(buyer1.address)).to.equal(3);
        //         expect((await SimpleSmolNFT.ownerOf(listings_list[0].token_id)).toLowerCase()).to.equal(buyer1.address.toLowerCase());
        //         expect((await SimpleSmolNFT.ownerOf(listings_list[1].token_id)).toLowerCase()).to.equal(buyer1.address.toLowerCase());
        //         expect((await SimpleSmolNFT.ownerOf(listings_list[2].token_id)).toLowerCase()).to.equal(buyer1.address.toLowerCase());

        //         const totalSpent = listings_list[0].price + listings_list[1].price + listings_list[2].price;
        //         const calculateFees = await TreasureMarketplaceMultiBuyer.calculateFee(totalSpent);

        //         expect(await MagicToken.balanceOf(buyer1.address)).to.equal(buyerMagicTokenBalanceBefore.sub(calculateFees.add(totalSpent)));
        //         expect(await MagicToken.balanceOf(feeRecipient.address)).to.equal(calculateFees);
        //         expect(await MagicToken.balanceOf(seller.address)).to.equal((sellerMagicTokenBalanceBefore.add(totalSpent)).sub((BigNumber.from(totalSpent)).mul(BigNumber.from(treasureMarketplaceFee)).div(BigNumber.from(treasureMarketplaceFeeOutOfUnits))));
        //         expect(await MagicToken.balanceOf(TreasureMarketplaceMultiBuyer.address)).to.equal(0);
        //     });

        //     it("Price lowered but should buy multiple ERC721 All Try Catch and succeed and pay fees", async function () {

        //         let discount = 10;

        //         const buyer1 = (await ethers.getSigners())[0];

        //         const buyerMagicTokenBalanceBefore = await MagicToken.balanceOf(buyer1.address);
        //         const sellerMagicTokenBalanceBefore = await MagicToken.balanceOf(seller.address);

        //         let contractAddresses = [SimpleSmolNFT.address, SimpleSmolNFT.address, SimpleSmolNFT.address];

        //         let tokenIds = [listings_list[0].token_id, listings_list[1].token_id, listings_list[2].token_id];
        //         let amounts = [1, 1, 1];
        //         let prices = [listings_list[0].price, listings_list[1].price, listings_list[2].price];

        //         let owners = [listings_list[0].seller.address, listings_list[1].seller.address, listings_list[2].seller.address];

        //         await TreasureMarketplace.connect(seller).updateListing(SimpleSmolNFT.address, listings_list[0].token_id, listings_list[0].amount, listings_list[0].price - discount, listings_list[0].expiration_time);

        //         await MagicToken.connect(buyer1).approve(TreasureMarketplaceMultiBuyer.address, BigNumber.from("115792089237316195423570985008687907853269984665640564039457584007913129639935"));

        //         await TreasureMarketplaceMultiBuyer.connect(buyer1).multiBuyERC721UsingPaymentTokenWithTryCatch(contractAddresses, tokenIds, owners, amounts, prices);
        //         expect(await SimpleSmolNFT.balanceOf(buyer1.address)).to.equal(3);
        //         expect((await SimpleSmolNFT.ownerOf(listings_list[0].token_id)).toLowerCase()).to.equal(buyer1.address.toLowerCase());
        //         expect((await SimpleSmolNFT.ownerOf(listings_list[1].token_id)).toLowerCase()).to.equal(buyer1.address.toLowerCase());
        //         expect((await SimpleSmolNFT.ownerOf(listings_list[2].token_id)).toLowerCase()).to.equal(buyer1.address.toLowerCase());

        //         const totalSpent = listings_list[0].price - discount + listings_list[1].price + listings_list[2].price;
        //         const calculateFees = await TreasureMarketplaceMultiBuyer.calculateFee(totalSpent);

        //         expect(await MagicToken.balanceOf(buyer1.address)).to.equal(buyerMagicTokenBalanceBefore.sub(calculateFees.add(totalSpent)));
        //         expect(await MagicToken.balanceOf(feeRecipient.address)).to.equal(calculateFees);
        //         expect(await MagicToken.balanceOf(seller.address)).to.equal((sellerMagicTokenBalanceBefore.add(totalSpent)).sub((BigNumber.from(totalSpent)).mul(BigNumber.from(treasureMarketplaceFee)).div(BigNumber.from(treasureMarketplaceFeeOutOfUnits))));
        //         expect(await MagicToken.balanceOf(TreasureMarketplaceMultiBuyer.address)).to.equal(0);
        //     });

        //     it("Should try to buy multiple ERC721 All Try Catch and succeed but fail if price is set higher and pay fees.", async function () {

        //         const buyer1 = (await ethers.getSigners())[0];

        //         const buyerMagicTokenBalanceBefore = await MagicToken.balanceOf(buyer1.address);
        //         const sellerMagicTokenBalanceBefore = await MagicToken.balanceOf(seller.address);

        //         let contractAddresses = [SimpleSmolNFT.address, SimpleSmolNFT.address, SimpleSmolNFT.address];

        //         let tokenIds = [listings_list[0].token_id, listings_list[1].token_id, listings_list[2].token_id];
        //         let amounts = [1, 1, 1];
        //         let prices = [listings_list[0].price, listings_list[1].price, listings_list[2].price];

        //         let owners = [listings_list[0].seller.address, listings_list[1].seller.address, listings_list[2].seller.address];

        //         await TreasureMarketplace.connect(seller).updateListing(SimpleSmolNFT.address, listings_list[0].token_id, listings_list[0].amount, listings_list[0].price + 1, listings_list[0].expiration_time);

        //         await MagicToken.connect(buyer1).approve(TreasureMarketplaceMultiBuyer.address, BigNumber.from("115792089237316195423570985008687907853269984665640564039457584007913129639935"));

        //         await TreasureMarketplaceMultiBuyer.connect(buyer1).multiBuyERC721UsingPaymentTokenWithTryCatch(contractAddresses, tokenIds, owners, amounts, prices);
        //         expect(await SimpleSmolNFT.balanceOf(buyer1.address)).to.equal(2);
        //         expect((await SimpleSmolNFT.ownerOf(listings_list[0].token_id)).toLowerCase()).to.equal(seller.address.toLowerCase());
        //         expect((await SimpleSmolNFT.ownerOf(listings_list[1].token_id)).toLowerCase()).to.equal(buyer1.address.toLowerCase());
        //         expect((await SimpleSmolNFT.ownerOf(listings_list[2].token_id)).toLowerCase()).to.equal(buyer1.address.toLowerCase());

        //         const totalSpent = listings_list[1].price + listings_list[2].price;
        //         const calculateFees = await TreasureMarketplaceMultiBuyer.calculateFee(totalSpent);

        //         expect(await MagicToken.balanceOf(buyer1.address)).to.equal(buyerMagicTokenBalanceBefore.sub(calculateFees.add(totalSpent)));
        //         expect(await MagicToken.balanceOf(feeRecipient.address)).to.equal(calculateFees);
        //         expect(await MagicToken.balanceOf(seller.address)).to.equal((sellerMagicTokenBalanceBefore.add(totalSpent)).sub((BigNumber.from(totalSpent)).mul(BigNumber.from(treasureMarketplaceFee)).div(BigNumber.from(treasureMarketplaceFeeOutOfUnits))));
        //         expect(await MagicToken.balanceOf(TreasureMarketplaceMultiBuyer.address)).to.equal(0);
        //     });

        //     it("Should try to buy multiple ERC721 but only succeed the 1st and pay fees.", async function () {

        //         const buyer1 = (await ethers.getSigners())[0];

        //         const buyerMagicTokenBalanceBefore = await MagicToken.balanceOf(buyer1.address);
        //         const sellerMagicTokenBalanceBefore = await MagicToken.balanceOf(seller.address);

        //         let contractAddresses = [SimpleSmolNFT.address, SimpleSmolNFT.address, SimpleSmolNFT.address];

        //         let tokenIds = [listings_list[0].token_id, 543543, listings_list[2].token_id];
        //         let amounts = [1, 1, 1];
        //         let prices = [listings_list[0].price, listings_list[1].price, 10];

        //         let owners = [listings_list[0].seller.address, listings_list[1].seller.address, listings_list[2].seller.address];

        //         let totalPrice = listings_list[0].price + listings_list[1].price + listings_list[2].price;

        //         await MagicToken.connect(buyer1).approve(TreasureMarketplaceMultiBuyer.address, BigNumber.from("115792089237316195423570985008687907853269984665640564039457584007913129639935"));

        //         await TreasureMarketplaceMultiBuyer.multiBuyERC721UsingPaymentTokenWithTryCatch(contractAddresses, tokenIds, owners, amounts, prices);
        //         expect(await SimpleSmolNFT.balanceOf(buyer1.address)).to.equal(1);
        //         expect((await SimpleSmolNFT.ownerOf(listings_list[0].token_id)).toLowerCase()).to.equal(buyer1.address.toLowerCase());
        //         expect((await SimpleSmolNFT.ownerOf(listings_list[1].token_id)).toLowerCase()).to.equal(seller.address.toLowerCase());
        //         expect((await SimpleSmolNFT.ownerOf(listings_list[2].token_id)).toLowerCase()).to.equal(seller.address.toLowerCase());

        //         const totalSpent = listings_list[0].price;
        //         const calculateFees = await TreasureMarketplaceMultiBuyer.calculateFee(totalSpent);

        //         expect(await MagicToken.balanceOf(buyer1.address)).to.equal(buyerMagicTokenBalanceBefore.sub(calculateFees.add(totalSpent)));
        //         expect(await MagicToken.balanceOf(feeRecipient.address)).to.equal(calculateFees);
        //         expect(await MagicToken.balanceOf(seller.address)).to.equal((sellerMagicTokenBalanceBefore.add(totalSpent)).sub((BigNumber.from(totalSpent)).mul(BigNumber.from(treasureMarketplaceFee)).div(BigNumber.from(treasureMarketplaceFeeOutOfUnits))));
        //         expect(await MagicToken.balanceOf(TreasureMarketplaceMultiBuyer.address)).to.equal(0);
        //     });

        //     it("Should try to buy 3 ERC721 but fail one only because got frontran and pay fees.", async function () {

        //         const buyer1 = (await ethers.getSigners())[0];

        //         const sellerMagicTokenBalanceBefore = await MagicToken.balanceOf(seller.address);
        //         const buyerMagicTokenBalanceBefore = await MagicToken.balanceOf(buyer1.address);
        //         const buyer2MagicTokenBalanceBefore = await MagicToken.balanceOf(buyer2.address);

        //         let contractAddresses = [SimpleSmolNFT.address, SimpleSmolNFT.address, SimpleSmolNFT.address];

        //         let amounts = [1, 1, 1];
        //         let prices = [listings_list[0].price, listings_list[1].price, listings_list[2].price];

        //         let owners = [listings_list[0].seller.address, listings_list[1].seller.address, listings_list[2].seller.address];

        //         let totalPrice = listings_list[0].price + listings_list[1].price + listings_list[2].price;

        //         let tokenIds = [listings_list[0].token_id, listings_list[1].token_id, listings_list[2].token_id];

        //         await MagicToken.connect(buyer2).approve(TreasureMarketplace.address, buyerMagicTokenBalanceBefore);

        //         await TreasureMarketplace.connect(buyer2).buyItem(SimpleSmolNFT.address, listings_list[0].token_id, listings_list[0].seller.address, amounts[0]);

        //         await MagicToken.connect(buyer1).approve(TreasureMarketplaceMultiBuyer.address, BigNumber.from("115792089237316195423570985008687907853269984665640564039457584007913129639935"));

        //         await TreasureMarketplaceMultiBuyer.connect(buyer1).multiBuyERC721UsingPaymentTokenWithTryCatch(contractAddresses, tokenIds, owners, amounts, prices);
        //         expect(await SimpleSmolNFT.balanceOf(buyer1.address)).to.equal(2);
        //         expect((await SimpleSmolNFT.ownerOf(listings_list[0].token_id)).toLowerCase()).to.equal(buyer2.address.toLowerCase());
        //         expect((await SimpleSmolNFT.ownerOf(listings_list[1].token_id)).toLowerCase()).to.equal(buyer1.address.toLowerCase());
        //         expect((await SimpleSmolNFT.ownerOf(listings_list[2].token_id)).toLowerCase()).to.equal(buyer1.address.toLowerCase());

        //         const totalSpentBuyer1 = listings_list[1].price + listings_list[2].price;
        //         const totalSpentBuyer2 = listings_list[0].price;
        //         const calculateFees = await TreasureMarketplaceMultiBuyer.calculateFee(totalSpentBuyer1);
        //         const calculateFees2 = await TreasureMarketplaceMultiBuyer.calculateFee(totalSpentBuyer2);

        //         expect(await MagicToken.balanceOf(buyer1.address)).to.equal(buyerMagicTokenBalanceBefore.sub(calculateFees.add(totalSpentBuyer1)));
        //         expect(await MagicToken.balanceOf(feeRecipient.address)).to.equal(calculateFees);
        //         expect(await MagicToken.balanceOf(buyer2.address)).to.equal(buyer2MagicTokenBalanceBefore.sub(totalSpentBuyer2));
        //         expect(await MagicToken.balanceOf(seller.address)).to.equal((sellerMagicTokenBalanceBefore.add(totalSpentBuyer1 + totalSpentBuyer2)).sub((BigNumber.from(totalSpentBuyer1 + totalSpentBuyer2)).mul(BigNumber.from(treasureMarketplaceFee)).div(BigNumber.from(treasureMarketplaceFeeOutOfUnits))));
        //         expect(await MagicToken.balanceOf(TreasureMarketplaceMultiBuyer.address)).to.equal(0);
        //     });

        //     it("Should try to buy multiple ERC721 using Try Catch but All failed and pay no fees.", async function () {

        //         const buyer1 = (await ethers.getSigners())[0];

        //         const buyerMagicTokenBalanceBefore = await MagicToken.balanceOf(buyer1.address);
        //         const sellerMagicTokenBalanceBefore = await MagicToken.balanceOf(seller.address);

        //         let contractAddresses = [SimpleSmolNFT.address, SimpleSmolNFT.address, SimpleSmolNFT.address];

        //         let tokenIds = [543543, 654654, 87687];
        //         let amounts = [1, 1, 1];
        //         let prices = [listings_list[0].price, listings_list[1].price, listings_list[2].price];

        //         let owners = [listings_list[0].seller.address, listings_list[1].seller.address, listings_list[2].seller.address];

        //         await MagicToken.connect(buyer1).approve(TreasureMarketplaceMultiBuyer.address, BigNumber.from("115792089237316195423570985008687907853269984665640564039457584007913129639935"));

        //         expect(TreasureMarketplaceMultiBuyer.connect(buyer1).multiBuyERC721UsingPaymentTokenWithTryCatch(contractAddresses, tokenIds, owners, amounts, prices)).to.be.revertedWith("All tokens failed to be bought!");
        //         expect(await SimpleSmolNFT.balanceOf(buyer1.address)).to.equal(0);
        //         expect((await SimpleSmolNFT.ownerOf(listings_list[0].token_id)).toLowerCase()).to.equal(seller.address.toLowerCase());
        //         expect((await SimpleSmolNFT.ownerOf(listings_list[1].token_id)).toLowerCase()).to.equal(seller.address.toLowerCase());
        //         expect((await SimpleSmolNFT.ownerOf(listings_list[2].token_id)).toLowerCase()).to.equal(seller.address.toLowerCase());

        //         expect(await MagicToken.balanceOf(buyer1.address)).to.equal(buyerMagicTokenBalanceBefore);
        //         expect(await MagicToken.balanceOf(feeRecipient.address)).to.equal(0);
        //         expect(await MagicToken.balanceOf(seller.address)).to.equal(sellerMagicTokenBalanceBefore);
        //         expect(await MagicToken.balanceOf(TreasureMarketplaceMultiBuyer.address)).to.equal(0);
        //     });



        //     it("Should buy multiple ERC721 All Atomic and succeed and pay fees", async function () {

        //         const buyer1 = (await ethers.getSigners())[0];

        //         const buyerMagicTokenBalanceBefore = await MagicToken.balanceOf(buyer1.address);
        //         const sellerMagicTokenBalanceBefore = await MagicToken.balanceOf(seller.address);

        //         let contractAddresses = [SimpleSmolNFT.address, SimpleSmolNFT.address, SimpleSmolNFT.address];

        //         let tokenIds = [listings_list[0].token_id, listings_list[1].token_id, listings_list[2].token_id];
        //         let amounts = [1, 1, 1];
        //         let prices = [listings_list[0].price, listings_list[1].price, listings_list[2].price];

        //         let owners = [listings_list[0].seller.address, listings_list[1].seller.address, listings_list[2].seller.address];

        //         await MagicToken.connect(buyer1).approve(TreasureMarketplaceMultiBuyer.address, BigNumber.from("115792089237316195423570985008687907853269984665640564039457584007913129639935"));

        //         await TreasureMarketplaceMultiBuyer.connect(buyer1).multiBuyERC721UsingPaymentTokenAllAtomic(contractAddresses, tokenIds, owners, amounts, prices);
        //         expect(await SimpleSmolNFT.balanceOf(buyer1.address)).to.equal(3);
        //         expect((await SimpleSmolNFT.ownerOf(listings_list[0].token_id)).toLowerCase()).to.equal(buyer1.address.toLowerCase());
        //         expect((await SimpleSmolNFT.ownerOf(listings_list[1].token_id)).toLowerCase()).to.equal(buyer1.address.toLowerCase());
        //         expect((await SimpleSmolNFT.ownerOf(listings_list[2].token_id)).toLowerCase()).to.equal(buyer1.address.toLowerCase());

        //         const totalSpent = listings_list[0].price + listings_list[1].price + listings_list[2].price;
        //         const calculateFees = await TreasureMarketplaceMultiBuyer.calculateFee(totalSpent);

        //         expect(await MagicToken.balanceOf(buyer1.address)).to.equal(buyerMagicTokenBalanceBefore.sub(calculateFees.add(totalSpent)));
        //         expect(await MagicToken.balanceOf(feeRecipient.address)).to.equal(calculateFees);
        //         expect(await MagicToken.balanceOf(seller.address)).to.equal((sellerMagicTokenBalanceBefore.add(totalSpent)).sub((BigNumber.from(totalSpent)).mul(BigNumber.from(treasureMarketplaceFee)).div(BigNumber.from(treasureMarketplaceFeeOutOfUnits))));
        //         expect(await MagicToken.balanceOf(TreasureMarketplaceMultiBuyer.address)).to.equal(0);
        //     });


        //     it("Should try buy multiple ERC721 All Atomic but fail and revert since price is set higher and pay no fees", async function () {

        //         const buyer1 = (await ethers.getSigners())[0];

        //         const buyerMagicTokenBalanceBefore = await MagicToken.balanceOf(buyer1.address);
        //         const sellerMagicTokenBalanceBefore = await MagicToken.balanceOf(seller.address);

        //         let contractAddresses = [SimpleSmolNFT.address, SimpleSmolNFT.address, SimpleSmolNFT.address];

        //         let tokenIds = [listings_list[0].token_id, listings_list[1].token_id, listings_list[2].token_id];
        //         let amounts = [1, 1, 1];
        //         let prices = [listings_list[0].price, listings_list[1].price, listings_list[2].price];

        //         let owners = [listings_list[0].seller.address, listings_list[1].seller.address, listings_list[2].seller.address];

        //         await TreasureMarketplace.connect(seller).updateListing(SimpleSmolNFT.address, listings_list[0].token_id, listings_list[0].amount, listings_list[0].price + 1, listings_list[0].expiration_time);

        //         await MagicToken.connect(buyer1).approve(TreasureMarketplaceMultiBuyer.address, BigNumber.from("115792089237316195423570985008687907853269984665640564039457584007913129639935"));

        //         await expect(TreasureMarketplaceMultiBuyer.connect(buyer1).multiBuyERC721UsingPaymentTokenAllAtomic(contractAddresses, tokenIds, owners, amounts, prices)).to.be.revertedWith("pricePerItem too high! Reverting...");
        //         expect(await SimpleSmolNFT.balanceOf(buyer1.address)).to.equal(0);
        //         expect((await SimpleSmolNFT.ownerOf(listings_list[0].token_id)).toLowerCase()).to.equal(seller.address.toLowerCase());
        //         expect((await SimpleSmolNFT.ownerOf(listings_list[1].token_id)).toLowerCase()).to.equal(seller.address.toLowerCase());
        //         expect((await SimpleSmolNFT.ownerOf(listings_list[2].token_id)).toLowerCase()).to.equal(seller.address.toLowerCase());

        //         expect(await MagicToken.balanceOf(buyer1.address)).to.equal(buyerMagicTokenBalanceBefore);
        //         expect(await MagicToken.balanceOf(feeRecipient.address)).to.equal(0);
        //         expect(await MagicToken.balanceOf(seller.address)).to.equal(sellerMagicTokenBalanceBefore);
        //         expect(await MagicToken.balanceOf(TreasureMarketplaceMultiBuyer.address)).to.equal(0);
        //     });


        //     it("Should try buy multiple ERC721 All Atomic even though price updated to lower and pay fees", async function () {

        //         const discount = 10;

        //         const buyer1 = (await ethers.getSigners())[0];

        //         const buyerMagicTokenBalanceBefore = await MagicToken.balanceOf(buyer1.address);
        //         const sellerMagicTokenBalanceBefore = await MagicToken.balanceOf(seller.address);

        //         let contractAddresses = [SimpleSmolNFT.address, SimpleSmolNFT.address, SimpleSmolNFT.address];

        //         let tokenIds = [listings_list[0].token_id, listings_list[1].token_id, listings_list[2].token_id];
        //         let amounts = [1, 1, 1];
        //         let prices = [listings_list[0].price, listings_list[1].price, listings_list[2].price];

        //         let owners = [listings_list[0].seller.address, listings_list[1].seller.address, listings_list[2].seller.address];

        //         await TreasureMarketplace.connect(seller).updateListing(SimpleSmolNFT.address, listings_list[0].token_id, listings_list[0].amount, listings_list[0].price - discount, listings_list[0].expiration_time);

        //         await MagicToken.connect(buyer1).approve(TreasureMarketplaceMultiBuyer.address, BigNumber.from("115792089237316195423570985008687907853269984665640564039457584007913129639935"));

        //         await TreasureMarketplaceMultiBuyer.connect(buyer1).multiBuyERC721UsingPaymentTokenAllAtomic(contractAddresses, tokenIds, owners, amounts, prices);
        //         expect(await SimpleSmolNFT.balanceOf(buyer1.address)).to.equal(3);
        //         expect((await SimpleSmolNFT.ownerOf(listings_list[0].token_id)).toLowerCase()).to.equal(buyer1.address.toLowerCase());
        //         expect((await SimpleSmolNFT.ownerOf(listings_list[1].token_id)).toLowerCase()).to.equal(buyer1.address.toLowerCase());
        //         expect((await SimpleSmolNFT.ownerOf(listings_list[2].token_id)).toLowerCase()).to.equal(buyer1.address.toLowerCase());

        //         const totalSpent = listings_list[0].price + listings_list[1].price + listings_list[2].price;
        //         const calculateFees = await TreasureMarketplaceMultiBuyer.calculateFee(totalSpent - discount);

        //         expect(await MagicToken.balanceOf(buyer1.address)).to.equal(buyerMagicTokenBalanceBefore.sub(calculateFees.add(totalSpent - discount)));
        //         expect(await MagicToken.balanceOf(seller.address)).to.equal((sellerMagicTokenBalanceBefore.add(totalSpent - discount)).sub((BigNumber.from(totalSpent - discount)).mul(BigNumber.from(treasureMarketplaceFee)).div(BigNumber.from(treasureMarketplaceFeeOutOfUnits))));
        //         expect(await MagicToken.balanceOf(TreasureMarketplaceMultiBuyer.address)).to.equal(0);
        //     });

        // });
    });
});
