// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./erc404.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

// https://texas404.com
contract Texas404 is ERC404 {
    string public baseTokenURI;

    constructor() ERC404("Texas404", "txs", 18, 2598960, msg.sender) {
        balanceOf[msg.sender] = 2598960 * 10 ** 18;
    }

    function withdraw() public onlyOwner {
        uint balance = balanceOf[address(this)];
        balanceOf[address(this)] = 0;
        balanceOf[owner()] += balance;
    }

    function withdrawETH() public onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    function setTokenURI(string memory _tokenURI) public onlyOwner {
        baseTokenURI = _tokenURI;
    }

    function tokenURI(uint256 id) public view override returns (string memory) {
        if (bytes(baseTokenURI).length > 0) {
            return string.concat(baseTokenURI, Strings.toString(id), ".json");
        } else {
            return
                string.concat(
                    "https://texas404.com/nft/",
                    Strings.toString(id),
                    ".json"
                );
        }
    }
}
