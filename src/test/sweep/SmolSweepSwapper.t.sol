// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@forge-std/src/Test.sol";
import "@contracts/sweep/SmolSweeper.sol";

import "@contracts/sweep/structs/BuyOrder.sol";

import "@contracts/treasure/trove/TroveMarketplace.sol";
import "@contracts/treasure/assets/magic-token/Magic.sol";
import "@contracts/weth/WETH9.sol";
import "@contracts/assets/erc721/NFTERC721.sol";
import "@contracts/assets/erc1155/NFTERC1155.sol";
import "@contracts/token/ANFTReceiver.sol";

import "@contracts/sweep/interfaces/ISmolSweeper.sol";

import "@contracts/sweep/diamond/interfaces/IDiamondCut.sol";
import "@contracts/sweep/diamond/facets/DiamondCutFacet.sol";
import "@contracts/sweep/diamond/facets/OwnershipFacet.sol";
import "@contracts/sweep/diamond/facets/sweep/BaseSweepFacet.sol";
import "@contracts/sweep/diamond/facets/sweep/SweepFacet.sol";
import "@contracts/sweep/diamond/facets/sweep/SweepSwapFacet.sol";
import {DiamondLoupeFacet} from "@contracts/sweep/diamond/facets/DiamondLoupeFacet.sol";
import "@contracts/sweep/diamond/Diamond.sol";
import "@contracts/sweep/SmolSweepDiamondInit.sol";
import {DiamondInit} from "@contracts/sweep/diamond/upgradeInitializers/DiamondInit.sol";

contract SmolSweeperTest is Test, AERC721Receiver, IDiamondCut {
  SmolSweeper public smolsweep;
  DiamondCutFacet dCutFacet;
  DiamondLoupeFacet dLoupe;
  OwnershipFacet ownerF;
  BaseSweepFacet baseF;
  SweepFacet sweepF;
  SweepSwapFacet sweepSwapF;
  IDiamondInit init;

  TroveMarketplace public trove;
  Magic public magic;
  WETH9 public weth;
  NFTERC721 public erc721;
  NFTERC721 public erc721ETH;

  NFTERC1155 public erc1155;

  address public OWNER;
  address public constant NOT_OWNER =
    0x0000000000000000000000000000000000000001;
  address public constant NEW_OWNER =
    0x0000000000000000000000000000000000000002;
  address public constant BUYER = 0x0000000000000000000000000000000000000003;
  address[] public SELLERS = [
    0x0000000000000000000000000000000000000004,
    0x0000000000000000000000000000000000000005,
    0x0000000000000000000000000000000000000006
  ];

  function setUp() public {
    OWNER = address(this);

    magic = new Magic();
    weth = new WETH9();
    erc721 = new NFTERC721();
    erc721ETH = new NFTERC721();
    erc1155 = new NFTERC1155();

    trove = new TroveMarketplace();
    trove.initialize(0, OWNER, magic);
    trove.setWeth(address(weth));
    trove.setTokenApprovalStatus(
      address(erc721),
      TroveMarketplace.TokenApprovalStatus.ERC_721_APPROVED,
      address(magic)
    );

    trove.setTokenApprovalStatus(
      address(erc721ETH),
      TroveMarketplace.TokenApprovalStatus.ERC_721_APPROVED,
      address(weth)
    );

    //deploy facets
    dCutFacet = new DiamondCutFacet();
    smolsweep = new SmolSweeper(address(this), address(dCutFacet));
    dLoupe = new DiamondLoupeFacet();
    ownerF = new OwnershipFacet();
    baseF = new BaseSweepFacet();
    sweepF = new SweepFacet();
    sweepSwapF = new SweepSwapFacet();

    init = new SmolSweepDiamondInit();
    // init = new DiamondInit();

    //build cut struct
    FacetCut[] memory cut = new FacetCut[](6);

    cut[0] = (
      FacetCut({
        facetAddress: address(dLoupe),
        action: FacetCutAction.Add,
        functionSelectors: generateSelectors("DiamondLoupeFacet")
      })
    );

    cut[1] = (
      FacetCut({
        facetAddress: address(ownerF),
        action: FacetCutAction.Add,
        functionSelectors: generateSelectors("OwnershipFacet")
      })
    );

    cut[2] = (
      FacetCut({
        facetAddress: address(sweepF),
        action: FacetCutAction.Add,
        functionSelectors: generateSelectors("SweepFacet")
      })
    );

    cut[3] = (
      FacetCut({
        facetAddress: address(baseF),
        action: FacetCutAction.Add,
        functionSelectors: generateSelectors("BaseSweepFacet")
      })
    );

    cut[4] = (
      FacetCut({
        facetAddress: address(sweepSwapF),
        action: FacetCutAction.Add,
        functionSelectors: generateSelectors("SweepSwapFacet")
      })
    );

    cut[5] = (
      FacetCut({
        facetAddress: address(smolsweep),
        action: FacetCutAction.Add,
        functionSelectors: generateSelectors("SmolSweeper")
      })
    );

    //upgrade diamond
    IDiamondCut(address(smolsweep)).diamondCut(
      cut,
      address(init),
      abi.encodePacked(IDiamondInit.init.selector)
    );

    BaseSweepFacet(address(smolsweep)).addMarketplace(
      address(trove),
      address(magic)
    );

    BaseSweepFacet(address(smolsweep)).addMarketplace(
      address(0xE5c7b4865D7f2B08FaAdF3F6d392E6D6Fa7B903C),
      address(0)
    );
  }

  function generateSelectors(string memory _facetName)
    internal
    returns (bytes4[] memory selectors)
  {
    string[] memory cmd = new string[](4);
    // cmd[0] = "ls";
    cmd[0] = "node";
    cmd[1] = "scripts/genSelectors.js";
    cmd[2] = _facetName;
    cmd[3] = "fout";
    bytes memory res = vm.ffi(cmd);
    selectors = abi.decode(res, (bytes4[]));
  }

  function diamondCut(
    FacetCut[] calldata _diamondCut,
    address _init,
    bytes calldata _calldata
  ) external override {}

  function test_owner() public {
    assertEq(IERC173(address(smolsweep)).owner(), OWNER);
  }

  function test_transferOwnership() public {
    IERC173(address(smolsweep)).transferOwnership(NEW_OWNER);
    assertEq(IERC173(address(smolsweep)).owner(), NEW_OWNER);
  }

  function test_buySingleFromTrove() public {
    magic.mint(BUYER, 1e18);

    erc721.safeMint(SELLERS[0]);
    uint256 tokenId = 0;

    uint128 price = 1e9;

    vm.startPrank(SELLERS[0], SELLERS[0]);
    erc721.setApprovalForAll(address(trove), true);
    trove.createListing(
      address(erc721),
      tokenId,
      1,
      price,
      uint64(block.timestamp + 100),
      address(magic)
    );
    vm.stopPrank();

    vm.startPrank(BUYER, BUYER);
    magic.approve(address(trove), price);
    BuyItemParams[] memory buyParams = new BuyItemParams[](1);
    buyParams[0] = BuyItemParams(
      address(erc721),
      tokenId,
      SELLERS[0],
      1,
      price,
      address(magic),
      false
    );
    trove.buyItems(buyParams);
  }
}
