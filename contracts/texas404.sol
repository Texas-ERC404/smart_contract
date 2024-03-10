// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./erc404.sol";
import "./texas_evaluate.sol";

// https://texas404.com
contract Texas404 is ERC404 {
    string public baseTokenURI;
    uint stage = 0;
    uint stageOnePrice = 0.0003 ether;
    uint stageTwoPrice = 0.0005 ether;
    uint stageOneAmount = 77968;
    uint stageTwoAmount = 129948;
    bool claimState = false;
    mapping(address => uint256) public rewardMap;

    constructor() ERC404("Texas404", "txc", 18, 2598960, msg.sender) {
        balanceOf[msg.sender] = (2598960 - stageOneAmount - stageTwoAmount) * 10 ** 18;
        balanceOf[address(this)] = (stageOneAmount + stageTwoAmount) * 10 ** 18;
    }

    function setStage(uint _stage) public onlyOwner {
        stage = _stage;
    }

    function withdraw(uint256 value)  public onlyOwner {
        require(balanceOf[address(this)] >= value);
        balanceOf[address(this)] -= value;
        balanceOf[rewardAddr()] += value;
    }

    function withdrawETH() public onlyOwner {
        payable(rewardAddr()).transfer(address(this).balance);
    }

    function buy(uint256 amount) public payable {
        require(stage != 0, 'Market closed!');

        if (stage == 1) {
            require(stageOneAmount >= amount, 'Insufficient quota for stage 1!');
            require((amount * stageOnePrice) == msg.value, 'Incorrect ETH value');
            _transfer(address(this), msg.sender, amount *_getUnit());
            stageOneAmount -= amount;
        }

        if (stage == 2) {
            require(stageTwoAmount >= amount, 'Insufficient quota for stage 2!');
            require((amount * stageTwoPrice) == msg.value, 'Incorrect ETH value');
            _transfer(address(this), msg.sender, amount *_getUnit());
            stageTwoAmount -= amount;
        }
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

    function setClaimState(bool _claimState) public onlyOwner {
        claimState = _claimState;
    }

    function setRewards(address[] memory addrs, uint256[] memory rewards) public onlyOwner {
        require(addrs.length == rewards.length, 'Wrong params!');
        for (uint i = 0; i < addrs.length; i++) {
            rewardMap[addrs[i]] = rewards[i];
        }
    }

    function claim() public {
        require(claimState == true, "Claiming is not open yet!");
        require(rewardMap[msg.sender] > 0, "Not in reward list!");

        IERC20(address(this)).transfer(msg.sender, rewardMap[msg.sender]);
        delete rewardMap[msg.sender];
    }
}
