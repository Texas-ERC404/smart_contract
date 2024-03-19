// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./erc404.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./texas_evaluate.sol";
import "./reward.sol";

// https://texas404.com
contract Texas404 is ERC404 {
    string public baseTokenURI;

    constructor() ERC404("Texas404", "TXC", 18, 2598960, msg.sender) {
        balanceOf[msg.sender] = 2598960 * 10 ** 18;
        Texas404Reward rwd = new Texas404Reward(address(this), msg.sender);
        setRewardContract(address(rwd));
    }

    function withdraw(uint256 value) public onlyOwner {
        require(balanceOf[address(this)] >= value);
        balanceOf[address(this)] -= value;
        balanceOf[rewardAddr()] += value;
    }

    function withdrawETH() public onlyOwner {
        payable(rewardAddr()).transfer(address(this).balance);
    }

    function setTokenURI(string memory _tokenURI) public onlyOwner {
        baseTokenURI = _tokenURI;
    }

    function tokenURI(uint256 id) public view override returns (string memory) {
        uint cv = card[id];
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
