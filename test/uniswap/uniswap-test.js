const { expect } = require("chai");
const { ethers } = require("hardhat");
const { BigNumber } = require("ethers");


const { getTimestampS,
    getTimestampMS } = require("../../src/utils/timeStamps.js")

function getTimestamp() {
    return getTimestampS(1000)
}

describe("Uniswap functions", function () {

    let accounts;

    let owner;


    let MagicToken;
    let TestInputToken;
    let WETH9;

    let UniswapV2ERC20;
    let UniswapV2Factory;
    let UniswapV2Router02;

    let UniswapV2PairFactory;

    let Swap;

    let Magic_WETH_Pair;
    let Magic_INPUT_TOKEN_PAIR;

    let MAX_UINT256 = BigNumber.from("0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff")

    beforeEach(async function () {
        accounts = await ethers.getSigners();

        owner = accounts[0];
        const MagicFactory = await ethers.getContractFactory("Magic");
        const UniswapV2ERC20Factory = await ethers.getContractFactory("UniswapV2ERC20");
        const UniswapV2FactoryFactory = await ethers.getContractFactory("UniswapV2Factory");
        const WETH9Factory = await ethers.getContractFactory("WETH9");
        const UniswapV2Router02Factory = await ethers.getContractFactory("UniswapV2Router02");
        const SwapFactory = await ethers.getContractFactory("Swap");
        const TestInputTokenFactory = await ethers.getContractFactory("TestInputToken");

        UniswapV2PairFactory = await ethers.getContractFactory("UniswapV2Pair");

        MagicToken = await MagicFactory.deploy();
        UniswapV2ERC20 = await UniswapV2ERC20Factory.deploy();
        UniswapV2Factory = await UniswapV2FactoryFactory.deploy(owner.address);
        WETH9 = await WETH9Factory.deploy();
        UniswapV2Router02 = await UniswapV2Router02Factory.deploy(UniswapV2Factory.address, WETH9.address);
        Swap = await SwapFactory.deploy(MagicToken.address, [UniswapV2Router02.address, UniswapV2Router02.address]);
        TestInputToken = await TestInputTokenFactory.deploy();

        const UniswapV2ERC20Address = await UniswapV2ERC20.deployed();
        const UniswapV2FactoryAddress = await UniswapV2Factory.deployed();
        const WETH9Address = await WETH9.deployed();
        const UniswapV2Router02Address = await UniswapV2Router02.deployed();
        const SwapAddress = await Swap.deployed();
        const TestInputTokenAddress = await TestInputToken.deployed();

    });

    // it("Should deploy the uniswap contract and set feeTo setter", async function () {
    //     expect(await UniswapV2Factory.feeToSetter()).to.equal(owner.address);
    // });


    describe("Swaps", function () {
        beforeEach(async function () {
            let amountETH = ethers.utils.parseEther("0.01");
            let amountMinETH = ethers.utils.parseEther("0.009");

            let amountMagic = ethers.utils.parseEther("1000000000");
            let amountMinMagic = ethers.utils.parseEther("90000000");

            await MagicToken.approve(UniswapV2Router02.address, MAX_UINT256);
            await TestInputToken.approve(UniswapV2Router02.address, MAX_UINT256);

            let createPair = await UniswapV2Factory.createPair(MagicToken.address, WETH9.address);
            let createPair2 = await UniswapV2Factory.createPair(MagicToken.address, TestInputToken.address);

            Magic_WETH_Pair = await UniswapV2PairFactory.attach(await UniswapV2Factory.allPairs(0));
            Magic_INPUT_TOKEN_PAIR = await UniswapV2PairFactory.attach(await UniswapV2Factory.allPairs(1));
            let res = await UniswapV2Router02.addLiquidityETH(MagicToken.address, amountMagic, amountMinMagic, amountMinETH, owner.address, getTimestamp(), { value: amountETH });
            let res2 = await UniswapV2Router02.addLiquidity(TestInputToken.address, MagicToken.address, amountMagic, amountMagic, amountMinMagic, amountMinMagic, owner.address, getTimestamp());
        });

        it("Should swap ETH for Exact Magic", async function () {

            let path = [WETH9.address, MagicToken.address]
            let slippage = 10;
            let total = 100;
            const ownerMagicBalanceBefore = await MagicToken.balanceOf(owner.address);

            let amount = ethers.utils.parseEther("0.01");
            let amountsIn = await UniswapV2Router02.getAmountsIn(amount, path);

            let amountsInBNWithSlippage = amountsIn[0].mul(slippage + total).div(total);

            const ownerETHBalanceBefore = await ethers.provider.getBalance(owner.address);
            let swap = await UniswapV2Router02.swapETHForExactTokens(amount, path, owner.address, getTimestamp(), { value: amountsInBNWithSlippage });
            let receipt = await swap.wait();

            const gasUsed = receipt.gasUsed
            const gasPrice = receipt.effectiveGasPrice
            const gasCost = gasUsed.mul(gasPrice);

            const ownerETHBalanceAfter = await ethers.provider.getBalance(owner.address);
            const ownerMagicBalanceAfter = await MagicToken.balanceOf(owner.address);

            expect((ownerETHBalanceBefore.sub(ownerETHBalanceAfter).sub(gasCost))).to.equal(amountsIn[0]);
            expect(ownerMagicBalanceAfter.sub(ownerMagicBalanceBefore)).to.equal(amount);
        });


        describe("Contract Swaps", function () {

            let amountOut;
            let exactAmountIn;
            let path;

            let slippage;
            let total;

            beforeEach(async function () {
                amountOut = ethers.utils.parseEther("0.01");
                exactAmountIn = ethers.utils.parseEther("0.01");
                slippage = 10;
                total = 100;
            });

            it("Should swap ETH for Exact Magic using contract", async function () {

                const SwapContractMagicBalanceBefore = await MagicToken.balanceOf(Swap.address);

                path = [WETH9.address, MagicToken.address];
                let amountsIn = await UniswapV2Router02.getAmountsIn(amountOut, path);

                let amountInBNWithSlippage = amountsIn[0].mul(slippage + total).div(total);

                const SwapContractETHBalanceBefore = amountInBNWithSlippage;

                let swap = await Swap.swapETHForExactPaymentTokens(amountOut, 0, getTimestamp(), { value: amountInBNWithSlippage });

                const SwapContractETHBalanceAfter = await ethers.provider.getBalance(Swap.address);
                const SwapContractMagicBalanceAfter = await MagicToken.balanceOf(Swap.address);

                expect((SwapContractETHBalanceBefore.sub(SwapContractETHBalanceAfter))).to.equal(amountsIn[0]);
                expect(SwapContractMagicBalanceAfter.sub(SwapContractMagicBalanceBefore)).to.equal(amountOut);
            });

            it("Should swap Input Tokens for Exact Magic using contract", async function () {
                const SwapContractMagicBalanceBefore = await MagicToken.balanceOf(Swap.address);
                const SwapContractInputTokenBalanceBefore = await TestInputToken.balanceOf(Swap.address);

                path = [TestInputToken.address, MagicToken.address];
                let amountsIn = await UniswapV2Router02.getAmountsIn(amountOut, path);

                let amountInBNWithSlippage = amountsIn[0].mul(slippage + total).div(total);
                await TestInputToken.transfer(Swap.address, amountInBNWithSlippage);

                await TestInputToken.approve(Swap.address, MAX_UINT256);

                let swap = await Swap.swapTokensForExactPaymentTokens(amountOut, amountInBNWithSlippage, TestInputToken.address, 0, getTimestamp());

                const SwapContractInputTokenBalanceAfter = await TestInputToken.balanceOf(Swap.address);
                const SwapContractMagicBalanceAfter = await MagicToken.balanceOf(Swap.address);

                expect((amountInBNWithSlippage.sub(SwapContractInputTokenBalanceAfter))).to.equal(amountsIn[0]);
                expect(SwapContractMagicBalanceAfter.sub(SwapContractMagicBalanceBefore)).to.equal(amountOut);
            });


            it("Should swap Exact ETH for Magic using contract", async function () {

                const SwapContractMagicBalanceBefore = await MagicToken.balanceOf(Swap.address);

                path = [WETH9.address, MagicToken.address];
                let amountsOut = await UniswapV2Router02.getAmountsOut(exactAmountIn, path);

                let amountOutBNWithSlippage = amountsOut[1].mul(total - slippage).div(total);

                const SwapContractETHBalanceBefore = exactAmountIn;

                let swap = await Swap.swapExactETHForPaymentTokens(amountOutBNWithSlippage, 0, getTimestamp(), { value: exactAmountIn });

                const SwapContractETHBalanceAfter = await ethers.provider.getBalance(Swap.address);
                const SwapContractMagicBalanceAfter = await MagicToken.balanceOf(Swap.address);

                expect((SwapContractETHBalanceBefore.sub(SwapContractETHBalanceAfter))).to.equal(amountsOut[0]);
                expect(SwapContractMagicBalanceAfter.sub(SwapContractMagicBalanceBefore)).to.equal(amountsOut[1]);
            });

            it("Should swap Exact Input Tokens for Magic using contract", async function () {
                await TestInputToken.transfer(Swap.address, exactAmountIn);
                const SwapContractMagicBalanceBefore = await MagicToken.balanceOf(Swap.address);
                const SwapContractInputTokenBalanceBefore = await TestInputToken.balanceOf(Swap.address);

                path = [TestInputToken.address, MagicToken.address];
                let amountsOut = await UniswapV2Router02.getAmountsOut(exactAmountIn, path);

                let amountOutBNWithSlippage = amountsOut[1].mul(total - slippage).div(total);

                let swap = await Swap.swapExactTokensForPaymentTokens(exactAmountIn, amountOutBNWithSlippage, TestInputToken.address, 0, getTimestamp());

                const SwapContractInputTokenBalanceAfter = await TestInputToken.balanceOf(Swap.address);
                const SwapContractMagicBalanceAfter = await MagicToken.balanceOf(Swap.address);

                expect((SwapContractInputTokenBalanceBefore.sub(SwapContractInputTokenBalanceAfter))).to.equal(exactAmountIn);
                expect(SwapContractMagicBalanceAfter.sub(SwapContractMagicBalanceBefore)).to.equal(amountsOut[1]);
            });


            it("Should swap Exact Magic for ETH using contract", async function () {
                await MagicToken.transfer(Swap.address, exactAmountIn);

                const SwapContractMagicBalanceBefore = await MagicToken.balanceOf(Swap.address);

                path = [MagicToken.address, WETH9.address];
                let amountsOut = await UniswapV2Router02.getAmountsOut(exactAmountIn, path);

                let amountOutBNWithSlippage = amountsOut[1].mul(total - slippage).div(total);

                const SwapContractETHBalanceBefore = await ethers.provider.getBalance(Swap.address);

                let swap = await Swap.swapExactPaymentTokensForETH(exactAmountIn, amountOutBNWithSlippage, 0, getTimestamp());

                const SwapContractETHBalanceAfter = await ethers.provider.getBalance(Swap.address);
                const SwapContractMagicBalanceAfter = await MagicToken.balanceOf(Swap.address);

                expect(SwapContractMagicBalanceBefore.sub(SwapContractMagicBalanceAfter)).to.equal(exactAmountIn);
                expect((SwapContractETHBalanceAfter.sub(SwapContractETHBalanceBefore))).to.equal(amountsOut[1]);
            });

            it("Should swap Exact Magic for Input Tokens using contract", async function () {
                await MagicToken.transfer(Swap.address, exactAmountIn);

                const SwapContractMagicBalanceBefore = await MagicToken.balanceOf(Swap.address);
                const SwapContractInputTokenBalanceBefore = await TestInputToken.balanceOf(Swap.address);

                path = [MagicToken.address, TestInputToken.address];
                let amountsOut = await UniswapV2Router02.getAmountsOut(exactAmountIn, path);

                let amountOutBNWithSlippage = amountsOut[1].mul(total - slippage).div(total);

                let swap = await Swap.swapExactPaymentTokensForTokens(exactAmountIn, amountOutBNWithSlippage, TestInputToken.address, 0, getTimestamp());

                const SwapContractInputTokenBalanceAfter = await TestInputToken.balanceOf(Swap.address);
                const SwapContractMagicBalanceAfter = await MagicToken.balanceOf(Swap.address);

                expect(SwapContractMagicBalanceBefore.sub(SwapContractMagicBalanceAfter)).to.equal(exactAmountIn);
                expect((SwapContractInputTokenBalanceAfter.sub(SwapContractInputTokenBalanceBefore))).to.equal(amountsOut[1]);
            });
        })
    });
});
