// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC165.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "../uniswap/v2-periphery/interfaces/IUniswapV2Router02.sol";

contract Swap is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bytes4 private constant INTERFACE_ID_ERC721 = 0x80ac58cd;
    bytes4 private constant INTERFACE_ID_ERC1155 = 0xd9b67a26;
    uint256 public constant BASIS_POINTS = 1000000000;

    uint256 public constant MAX_UINT256 =
        115792089237316195423570985008687907853269984665640564039457584007913129639935;

    uint256 public fees;
    address public feeRecipient;
    uint256 public minTotalPriceForFee = 1000000000;

    IERC20 public defaultPaymentToken;
    // address public constant WETH9 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    // address public WETH = 0xc778417E063141139Fce010982780140Aa0cD5Ab;

    IUniswapV2Router02[] public swapRouters;

    constructor(address _paymentToken, IUniswapV2Router02[] memory _swapRouters)
    {
        defaultPaymentToken = IERC20(_paymentToken);
        swapRouters = _swapRouters;
    }

    function getSwapRouterCount() public view returns (uint256) {
        return swapRouters.length;
    }

    function setDefaultPaymentToken(address _defaultPaymentToken) public {
        defaultPaymentToken = IERC20(_defaultPaymentToken);
    }

    function approveERC20TokenToContract(
        IERC20 _token,
        address _contract,
        uint256 _amount
    ) external onlyOwner nonReentrant {
        _token.safeApprove(address(_contract), uint256(_amount));
    }

    function transferERC20TokenToContract(
        IERC20 _token,
        address _contract,
        uint256 _amount
    ) external onlyOwner nonReentrant {
        _token.safeTransfer(address(_contract), uint256(_amount));
    }

    function addSwapRouter(IUniswapV2Router02 _router) external onlyOwner {
        swapRouters.push(_router);
    }

    function setSwapRouter(uint256 routerId, IUniswapV2Router02 _router)
        external
        onlyOwner
    {
        require(swapRouters.length < MAX_UINT256);
        swapRouters[routerId] = _router;
    }

    // _routerId: 0 for uniswap, 1 for sushiswap
    function calculateMinETHInputForOutputPaymentTokens(
        uint256 _outputPaymentTokenAmount,
        uint256 _routerId
    ) public view returns (uint256[] memory) {
        address[] memory path = new address[](2);
        IUniswapV2Router02 router = swapRouters[_routerId];
        path[0] = router.WETH();
        path[1] = address(defaultPaymentToken);
        return router.getAmountsIn(_outputPaymentTokenAmount, path);
    }

    // _routerId: 0 for uniswap, 1 for sushiswap
    function calculateMinTokensInputForOutputPaymentTokens(
        address _inputTokenAddress,
        uint256 _outputPaymentTokenAmount,
        uint256 _routerId
    ) public view returns (uint256[] memory) {
        address[] memory path = new address[](2);
        IUniswapV2Router02 router = swapRouters[_routerId];
        path[0] = _inputTokenAddress;
        path[1] = address(defaultPaymentToken);
        return router.getAmountsIn(_outputPaymentTokenAmount, path);
    }

    // _routerId: 0 for uniswap, 1 for sushiswap
    function swapETHForExactPaymentTokens(
        uint256 _amountOut,
        uint256 _routerId,
        uint256 _deadline
    ) public payable returns (uint256[] memory) {
        address[] memory path = new address[](2);
        IUniswapV2Router02 router = swapRouters[_routerId];
        path[0] = router.WETH();
        path[1] = address(defaultPaymentToken);
        return
            router.swapETHForExactTokens{value: msg.value}(
                _amountOut,
                path,
                address(this),
                _deadline
            );
    }

    // _routerId: 0 for uniswap, 1 for sushiswap
    function swapTokensForExactPaymentTokens(
        uint256 _amountOut,
        uint256 _amountInMax,
        address _inputERC20,
        uint256 _routerId,
        uint256 _deadline
    ) public returns (uint256[] memory) {
        address[] memory path = new address[](2);
        IUniswapV2Router02 router = swapRouters[_routerId];
        path[0] = _inputERC20;
        path[1] = address(defaultPaymentToken);
        IERC20(_inputERC20).approve(address(router), _amountInMax);
        return
            router.swapTokensForExactTokens(
                _amountOut,
                _amountInMax,
                path,
                address(this),
                _deadline
            );
    }

    // _routerId: 0 for uniswap, 1 for sushiswap
    function swapExactETHForPaymentTokens(
        uint256 _amountOutMin,
        uint256 _routerId,
        uint256 _deadline
    ) public payable returns (uint256[] memory) {
        address[] memory path = new address[](2);
        IUniswapV2Router02 router = swapRouters[_routerId];
        path[0] = router.WETH();
        path[1] = address(defaultPaymentToken);
        return
            router.swapExactETHForTokens{value: msg.value}(
                _amountOutMin,
                path,
                address(this),
                _deadline
            );
    }

    // _routerId: 0 for uniswap, 1 for sushiswap
    function swapExactTokensForPaymentTokens(
        uint256 _amountIn,
        uint256 _amountOutMin,
        address _inputERC20,
        uint256 _routerId,
        uint256 _deadline
    ) public returns (uint256[] memory) {
        address[] memory path = new address[](2);
        IUniswapV2Router02 router = swapRouters[_routerId];
        path[0] = _inputERC20;
        path[1] = address(defaultPaymentToken);
        IERC20(_inputERC20).approve(address(router), _amountIn);
        return
            router.swapExactTokensForTokens(
                _amountIn,
                _amountOutMin,
                path,
                address(this),
                _deadline
            );
    }

    // _routerId: 0 for uniswap, 1 for sushiswap
    function swapExactPaymentTokensForETH(
        uint256 _amountIn,
        uint256 _amountOutMin,
        uint256 _routerId,
        uint256 _deadline
    ) public returns (uint256[] memory) {
        address[] memory path = new address[](2);
        IUniswapV2Router02 router = swapRouters[_routerId];
        path[0] = address(defaultPaymentToken);
        path[1] = router.WETH();
        IERC20(defaultPaymentToken).approve(address(router), MAX_UINT256);
        return
            router.swapExactTokensForETH(
                _amountIn,
                _amountOutMin,
                path,
                address(this),
                _deadline
            );
    }

    // _routerId: 0 for uniswap, 1 for sushiswap
    function swapExactPaymentTokensForTokens(
        uint256 _amountIn,
        uint256 _amountOutMin,
        address _outputTokenAddress,
        uint256 _routerId,
        uint256 _deadline
    ) public returns (uint256[] memory) {
        address[] memory path = new address[](2);
        IUniswapV2Router02 router = swapRouters[_routerId];
        path[0] = address(defaultPaymentToken);
        path[1] = _outputTokenAddress;
        IERC20(defaultPaymentToken).approve(address(router), _amountIn);
        return
            router.swapExactTokensForTokens(
                _amountIn,
                _amountOutMin,
                path,
                address(this),
                _deadline
            );
    }

    receive() external payable {}

    fallback() external payable {}
}
