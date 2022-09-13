// SPDX-License-Identifier: MIT
pragma solidity >=0.4.0 <0.9.0;

import "@uniswap/v2-periphery/contracts/UniswapV2Router02.sol";
import "@forge-std/src/Test.sol";

contract SmolSweeperTest is Test {
  function setUp() public {}

  function testUniswap() public {
    UniswapV2Router02 router = new UniswapV2Router02(
      0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D,
      0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
    );

    console.log("UniswapV2Router02 deployed at %s", address(router));
    console.logBytes(at(address(router)));
  }

  function at(address _addr) internal view returns (bytes memory o_code) {
    assembly {
      // retrieve the size of the code, this needs assembly
      let size := extcodesize(_addr)
      // allocate output byte array - this could also be done without assembly
      // by using o_code = new bytes(size)
      o_code := mload(0x40)
      // new "memory end" including padding
      mstore(0x40, add(o_code, and(add(add(size, 0x20), 0x1f), not(0x1f))))
      // store length in memory
      mstore(o_code, size)
      // actually retrieve the code, this needs assembly
      extcodecopy(_addr, add(o_code, 0x20), 0, size)
    }
  }
}
