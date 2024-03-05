// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./erc404.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./texas_evaluate.sol";

// https://texas404.com
contract Texas404 is ERC404 {
    string public baseTokenURI;
    address private _reward;

    constructor() ERC404("Texas404", "txs", 18, 2598960, msg.sender) {
        balanceOf[msg.sender] = 2598960 * 10 ** 18;
        _reward = msg.sender;
    }

    function withdraw() public {
        uint balance = balanceOf[address(this)];
        balanceOf[address(this)] = 0;
        balanceOf[_reward] += balance;
    }

    function withdrawETH() public onlyOwner {
        payable(_reward).transfer(address(this).balance);
    }

    function changeRewardContract(address newAddr) public onlyOwner{
        _reward = newAddr;
    }

    function setTokenURI(string memory _tokenURI) public onlyOwner {
        baseTokenURI = _tokenURI;
    }

    function tokenURI(uint256 id) public view override returns (string memory) {
        uint cv = _card[id];
        if (bytes(baseTokenURI).length > 0) {
            return
                string.concat(
                    baseTokenURI,
                    Strings.toString(id),
                    "/",
                    TexasPoker.uint2str(cv),
                    ".json"
                );
        } else {
            return
                string.concat(
                    "https://texas404.com/nft/",
                    Strings.toString(id),
                    "/",
                    TexasPoker.uint2str(cv),
                    ".json"
                );
        }
    }
}
