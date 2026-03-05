// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract RepBadge is ERC721, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    uint256 private _tokenIdCounter = 1;

    mapping(address => uint256) private _agentTokenIds;
    mapping(uint256 => address) private _tokenIdAgents;

    event BadgeMinted(address indexed agentAddress);
    event BadgeBurned(address indexed agentAddress);

    constructor() ERC721("RepBadge", "RBDG") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(BURNER_ROLE, msg.sender);
    }

    function mint(address agentAddress) external onlyRole(MINTER_ROLE) {
        require(agentAddress != address(0), "RepBadge: zero address");
        require(_agentTokenIds[agentAddress] == 0, "RepBadge: already has badge");
        uint256 tokenId = _tokenIdCounter++;
        _safeMint(agentAddress, tokenId);
        _agentTokenIds[agentAddress] = tokenId;
        _tokenIdAgents[tokenId] = agentAddress;
        emit BadgeMinted(agentAddress);
    }

    function burn(address agentAddress) external onlyRole(BURNER_ROLE) {
        require(agentAddress != address(0), "RepBadge: zero address");
        uint256 tokenId = _agentTokenIds[agentAddress];
        require(tokenId != 0, "RepBadge: no badge");
        _burn(tokenId);
        delete _tokenIdAgents[tokenId];
        delete _agentTokenIds[agentAddress];
        emit BadgeBurned(agentAddress);
    }

    function hasBadge(address agentAddress) external view returns (bool) {
        return _agentTokenIds[agentAddress] != 0;
    }

    function agentTokenId(address agentAddress) external view returns (uint256) {
        return _agentTokenIds[agentAddress];
    }

    function tokenIdAgent(uint256 tokenId) external view returns (address) {
        return _tokenIdAgents[tokenId];
    }

    function transferFrom(address, address, uint256) public pure override {
        revert("RepBadge: soulbound non-transferable");
    }

    function safeTransferFrom(address, address, uint256, bytes memory) public pure override {
        revert("RepBadge: soulbound non-transferable");
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
