// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import '@openzeppelin/contracts/utils/math/Math.sol';
import '@openzeppelin/contracts/utils/Strings.sol';
import '@openzeppelin/contracts/utils/Counters.sol';


import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20FlashMint.sol";

// import "@openzeppelin/contracts/access/AccessControl.sol";
// import './School.sol';
// import './Land.sol';
import './MinterControl.sol';

contract School is Ownable {
    uint256 public constant WEEK = 7 days;
    /// @dev 18 decimals
    uint256 public iqPerWeek;
    /// @dev 18 decimals
    uint256 public totalIqStored;
    /// @dev unix timestamp
    uint256 public lastRewardTimestamp;
    uint256 public smolBrainSupply;

    SmolBrain public smolBrain;

    mapping(uint256 => uint256) public timestampJoined;

    event JoinSchool(uint256 tokenId);
    event DropSchool(uint256 tokenId);
    event SetIqPerWeek(uint256 iqPerWeek);
    event SmolBrainSet(address smolBrain);

    modifier onlySmolBrainOwner(uint256 _tokenId) {
        require(smolBrain.ownerOf(_tokenId) == msg.sender, "School: only owner can send to school");
        _;
    }

    modifier atSchool(uint256 _tokenId, bool expectedAtSchool) {
        require(isAtSchool(_tokenId) == expectedAtSchool, "School: wrong school attendance");
        _;
    }

    modifier updateTotalIQ(bool isJoining) {
        if (smolBrainSupply > 0) {
            totalIqStored = totalIQ();
        }
        lastRewardTimestamp = block.timestamp;
        isJoining ? smolBrainSupply++ : smolBrainSupply--;
        _;
    }

    function totalIQ() public view returns (uint256) {
        uint256 timeDelta = block.timestamp - lastRewardTimestamp;
        return totalIqStored + smolBrainSupply * iqPerWeek * timeDelta / WEEK;
    }

    function iqEarned(uint256 _tokenId) public view returns (uint256 iq) {
        if (timestampJoined[_tokenId] == 0) return 0;
        uint256 timedelta = block.timestamp - timestampJoined[_tokenId];
        iq = iqPerWeek * timedelta / WEEK;
    }

    function isAtSchool(uint256 _tokenId) public view returns (bool) {
        return timestampJoined[_tokenId] > 0;
    }

    function join(uint256 _tokenId)
        external
        onlySmolBrainOwner(_tokenId)
        atSchool(_tokenId, false)
        updateTotalIQ(true)
    {
        timestampJoined[_tokenId] = block.timestamp;
        emit JoinSchool(_tokenId);
    }

    function drop(uint256 _tokenId)
        external
        onlySmolBrainOwner(_tokenId)
        atSchool(_tokenId, true)
        updateTotalIQ(false)
    {
        smolBrain.schoolDrop(_tokenId, iqEarned(_tokenId));
        timestampJoined[_tokenId] = 0;
        emit DropSchool(_tokenId);
    }

    // ADMIN

    function setSmolBrain(address _smolBrain) external onlyOwner {
        smolBrain = SmolBrain(_smolBrain);
        emit SmolBrainSet(_smolBrain);
    }

    /// @param _iqPerWeek NUmber of IQ points to earn a week, 18 decimals
    function setIqPerWeek(uint256 _iqPerWeek) external onlyOwner {
        iqPerWeek = _iqPerWeek;
        emit SetIqPerWeek(_iqPerWeek);
    }
}




contract SmolBrain is MinterControl, ERC721Enumerable {
    using Strings for uint256;
    using Counters for Counters.Counter;

    uint256 constant LAST_MALE = 6710;
    uint256 constant LAST_FEMALE = 13421;

    enum Gender { Male, Female }

    Counters.Counter private _maleTokenIdTracker;
    Counters.Counter private _femaleTokenIdTracker;
    string public baseURI;

    /// @dev 18 decimals
    uint256 public brainMaxLevel;
    /// @dev 18 decimals
    uint256 public levelIQCost;

    School public school;
    Land public land;

    // tokenId => IQ
    mapping(uint256 => uint256) public brainz;

    event SmolBrainMint(address to, uint256 tokenId, Gender gender);
    event LevelIQCost(uint256 levelIQCost);
    event LandMaxLevel(uint256 brainMaxLevel);
    event SchoolSet(address school);
    event LandSet(address land);

    modifier onlySchool() {
        require(msg.sender == address(school), "SmolBrain: !school");
        _;
    }

    constructor(address _luckyWinner) ERC721("Smol Brain", "SmolBrain") {
        _femaleTokenIdTracker._value = LAST_MALE + 1;
        _mint(_luckyWinner, Gender.Male);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721Enumerable, AccessControl) returns (bool) {
        return ERC721Enumerable.supportsInterface(interfaceId) || AccessControl.supportsInterface(interfaceId);
    }

    function mintMale(address _to) external onlyMinter {
        _mint(_to, Gender.Male);
    }

    function mintFemale(address _to) external onlyMinter {
        _mint(_to, Gender.Female);
    }

    function getGender(uint256 _tokenId) public pure returns (Gender) {
        return _tokenId <= LAST_MALE ? Gender.Male : Gender.Female;
    }

    function tokenURI(uint256 _tokenId) public view override returns (string memory) {
        require(_exists(_tokenId), "SmolBrain: URI query for nonexistent token");

        uint256 level = Math.min(scanBrain(_tokenId) / levelIQCost, brainMaxLevel);
        return bytes(baseURI).length > 0 ?
            string(abi.encodePacked(
                baseURI,
                _tokenId.toString(),
                "/",
                level.toString()
            ))
            : "";
    }

    function scanBrain(uint256 _tokenId) public view returns (uint256 IQ) {
        IQ = brainz[_tokenId] + school.iqEarned(_tokenId);
    }

    function averageIQ() public view returns (uint256) {
        if (totalSupply() == 0) return 0;
        uint256 totalIQ = school.totalIQ();
        return totalIQ / totalSupply();
    }

    /// @param _tokenId tokenId of the land
    function schoolDrop(uint256 _tokenId, uint256 _iqEarned) external onlySchool {
        brainz[_tokenId] += _iqEarned;
    }

    function _mint(address _to, Gender _gender) internal {
        uint256 _tokenId;
        if (_gender == Gender.Male) {
            _tokenId = _maleTokenIdTracker.current();
            _maleTokenIdTracker.increment();
            require(_tokenId <= LAST_MALE, "SmolBrain: exceeded tokenId for male");
        } else {
            _tokenId = _femaleTokenIdTracker.current();
            _femaleTokenIdTracker.increment();
            require(_tokenId <= LAST_FEMALE, "SmolBrain: exceeded tokenId for female");
        }

        emit SmolBrainMint(_to, _tokenId, _gender);
        _safeMint(_to, _tokenId);
    }

    function _beforeTokenTransfer(
        address _from,
        address _to,
        uint256 _tokenId
    ) internal override {
        super._beforeTokenTransfer(_from, _to, _tokenId);

        if (address(school) != address(0))
            require(!school.isAtSchool(_tokenId), "SmolBrain: is at school. Drop school to transfer.");
        if (_from != address(0))
            land.upgradeSafe(land.tokenOfOwnerByIndex(_from, 0));
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    // ADMIN

    function setSchool(address _school) external onlyOwner {
        school = School(_school);
        emit SchoolSet(_school);
    }

    function setLand(address _land) external onlyOwner {
        land = Land(_land);
        emit LandSet(_land);
    }

    function setLevelIQCost(uint256 _levelIQCost) external onlyOwner {
        levelIQCost = _levelIQCost;
        emit LevelIQCost(_levelIQCost);
    }

    function setMaxLevel(uint256 _brainMaxLevel) external onlyOwner {
        brainMaxLevel = _brainMaxLevel;
        emit LandMaxLevel(_brainMaxLevel);
    }

    function setBaseURI(string memory _baseURItoSet) external onlyOwner {
        baseURI = _baseURItoSet;
    }
}


contract Land is MinterControl, ERC721Enumerable {
    using Strings for uint256;
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdTracker;
    string public baseURI;

    /// @dev 18 decimals
    uint256 public landMaxLevel;
    /// @dev 18 decimals
    uint256 public levelIQCost;

    /// @dev tokenId => land level
    mapping(uint256 => uint256) public landLevels;

    SmolBrain public smolBrain;

    event LandMint(address indexed to, uint256 tokenId);
    event LandUpgrade(uint256 indexed tokenId, uint256 availableLevel);
    event LandMaxLevel(uint256 landMaxLevel);
    event LevelIQCost(uint256 levelIQCost);
    event SmolBrainSet(address smolBrain);

    constructor() ERC721("Smol Brain Land", "SmolBrainLand") {}

    function supportsInterface(bytes4 interfaceId) public view override(ERC721Enumerable, AccessControl) returns (bool) {
        return ERC721Enumerable.supportsInterface(interfaceId) || AccessControl.supportsInterface(interfaceId);
    }

    function mint(address _to) external onlyMinter {
        emit LandMint(_to, _tokenIdTracker.current());

        _safeMint(_to, _tokenIdTracker.current());
        _tokenIdTracker.increment();
    }

    function tokenURI(uint256 _tokenId) public view override returns (string memory) {
        require(_exists(_tokenId), "Land: URI query for nonexistent token");

        (, uint256 availableLevel) = canUpgrade(_tokenId);
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, availableLevel.toString())) : "";
    }

    /// @param _tokenId tokenId of the land
    /// @return isUpgradeAvailable true if higher level is available
    /// @return availableLevel what level can land be upgraded to
    function canUpgrade(uint256 _tokenId) public view returns (bool isUpgradeAvailable, uint256 availableLevel) {
        uint256 highestIQ = findBiggestBrainIQ(ownerOf(_tokenId));
        uint256 averageIQ = smolBrain.averageIQ();
        uint256 maxLevel = Math.min(averageIQ / levelIQCost, landMaxLevel);
        availableLevel = Math.min(highestIQ / levelIQCost, maxLevel);
        uint256 storedLevel = landLevels[_tokenId];
        if (storedLevel < availableLevel) {
            isUpgradeAvailable = true;
        }
    }

    /// @param _owner owner of the land
    /// @return highestIQ IQ of the biggest brain
    function findBiggestBrainIQ(address _owner) public view returns (uint256 highestIQ) {
        uint256 length = smolBrain.balanceOf(_owner);

        for (uint256 i = 0; i < length; i++) {
            uint256 tokenId = smolBrain.tokenOfOwnerByIndex(_owner, i);
            uint256 IQ = smolBrain.scanBrain(tokenId);
            if (IQ > highestIQ) {
                highestIQ = IQ;
            }
        }
    }

    /// @param _tokenId tokenId of the land
    function upgrade(uint256 _tokenId) external {
        require(upgradeSafe(_tokenId), "Land: nothing to upgrade");
    }

    function upgradeSafe(uint256 _tokenId) public returns (bool) {
        (bool isUpgradeAvailable, uint256 availableLevel) = canUpgrade(_tokenId);
        if (isUpgradeAvailable) {
            landLevels[_tokenId] = availableLevel;
            emit LandUpgrade(_tokenId, availableLevel);
        }
        return isUpgradeAvailable;
    }

    function _beforeTokenTransfer(
        address _from,
        address _to,
        uint256 _tokenId
    ) internal override {
        super._beforeTokenTransfer(_from, _to, _tokenId);

        require(balanceOf(_to) == 0, "Land: can own only one land");
        if (_from != address(0)) upgradeSafe(_tokenId);
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    // ADMIN

    function setSmolBrain(address _smolBrain) external onlyOwner {
        smolBrain = SmolBrain(_smolBrain);
        emit SmolBrainSet(_smolBrain);
    }

    function setMaxLevel(uint256 _landMaxLevel) external onlyOwner {
        landMaxLevel = _landMaxLevel;
        emit LandMaxLevel(_landMaxLevel);
    }

    function setLevelIQCost(uint256 _levelIQCost) external onlyOwner {
        levelIQCost = _levelIQCost;
        emit LevelIQCost(_levelIQCost);
    }

    function setBaseURI(string memory _baseURItoSet) external onlyOwner {
        baseURI = _baseURItoSet;
    }
}