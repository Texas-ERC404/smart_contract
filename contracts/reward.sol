// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./erc404.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./texas_evaluate.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

// https://texas404.com
contract Texas404Reward is Ownable, EIP712 {
    bytes32 private constant CLAIM_TYPEHASH =
        keccak256("Claim(address user,uint256 value,uint256 nonce)");
    address public texas;
    error ERC2612InvalidSigner(address signer, address owner);
    mapping(uint256 => uint256) public used;

    event Claim(address indexed user, uint256 indexed value, uint256 nonce);

    constructor(address addr) Ownable(msg.sender) EIP712("texas404", "1") {
        texas = addr;
    }

    function changeTexasAddr(address newAddr) public onlyOwner {
        texas = newAddr;
    }

    function claim(
        uint256 value,
        uint256 nonce,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        bytes32 structHash = keccak256(
            abi.encode(CLAIM_TYPEHASH, msg.sender, value, nonce)
        );
        require(used[nonce] == 0);
        used[nonce] = 1;

        bytes32 hash = _hashTypedDataV4(structHash);

        address signer = ECDSA.recover(hash, v, r, s);
        if (signer != owner()) {
            revert ERC2612InvalidSigner(signer, owner());
        }
        IERC20(texas).transfer(msg.sender, value);
        emit Claim(msg.sender, value, nonce);
    }
}
