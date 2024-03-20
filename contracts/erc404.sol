//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "./texas_evaluate.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

abstract contract ERC721Receiver {
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external virtual returns (bytes4) {
        return ERC721Receiver.onERC721Received.selector;
    }
}

/// @notice ERC404
///         A gas-efficient, mixed ERC20 / ERC721 implementation
///         with native liquidity and fractionalization.
///
///         This is an experimental standard designed to integrate
///         with pre-existing ERC20 / ERC721 support as smoothly as
///         possible.
///
/// @dev    In order to support full functionality of ERC20 and ERC721
///         supply assumptions are made that slightly constraint usage.
///         Ensure decimals are sufficiently large (standard 18 recommended)
///         as ids are effectively encoded in the lowest range of amounts.
///
///         NFTs are spent on ERC20 functions in a FILO queue, this is by
///         design.
///
abstract contract ERC404 is Ownable {
    // Events
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 amount
    );
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed id
    );
    event ERC721Approval(
        address indexed owner,
        address indexed spender,
        uint256 indexed id
    );
    event ApprovalForAll(
        address indexed owner,
        address indexed operator,
        bool approved
    );

    // Errors
    error NotFound();
    error AlreadyExists();
    error InvalidRecipient();
    error InvalidSender();
    error UnsafeRecipient();

    error Unauthorized();
    error InvalidOwner();
    error InvalidOperator();

    // Metadata
    /// @dev Token name
    string public name;

    /// @dev Token symbol
    string public symbol;

    /// @dev Decimals for fractional representation
    uint8 public immutable decimals;

    /// @dev Total supply in fractionalized representation
    uint256 public immutable totalSupply;

    /// @dev Current mint counter, monotonically increasing to ensure accurate ownership
    uint256 public minted;
    uint256 public mintFee;

    /// @dev `keccak256(bytes("Transfer(address,address,uint256)"))`.
    uint256 private constant _TRANSFER_EVENT_SIGNATURE 
        = 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef;

    // Mappings
    /// @dev Balance of user in fractional representation
    mapping(address => uint256) public balanceOf;
    mapping(address => uint256) public nftBalanceOf;

    /// @dev Allowance of user in fractional representation
    mapping(address => mapping(address => uint256)) public allowance;

    /// @dev Approval in native representaion
    mapping(uint256 => address) public getApproved;

    /// @dev Approval for all in native representation
    mapping(address => mapping(address => bool)) public isApprovedForAll;

    /// @dev Owner of id in native representation
    mapping(uint256 => address) internal _ownerOf;

    /// @dev Array of owned ids in native representation
    mapping(address => mapping(TexasPoker.HandRank => uint256[]))
        internal _owned;

    /// @dev Tracks indices for the _owned mapping
    mapping(uint256 => uint256) internal _ownedIndex;

    mapping(uint256 => TexasPoker.HandRank) internal _rank;
    mapping(uint256 => uint256) public card;

    mapping(uint256 => address) public stakingOwner;
    address private _reward;

    // Constructor
    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        uint256 _totalNativeSupply,
        address _owner
    ) Ownable(_owner) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        totalSupply = _totalNativeSupply * (10 ** decimals);
        mintFee = _getUnit() / 20;
        _reward = _owner;
    }

    function evSend(address from, address to, uint256 amount) internal {
        /// @solidity memory-safe-assembly
        assembly {
            // Emit the {Transfer} event.
            mstore(0x00, amount)
            log3(0x00, 0x20, _TRANSFER_EVENT_SIGNATURE, shr(96, shl(96, from)), shr(96, shl(96, to)))
        }
    }

    /// @notice Function to find owner of a given native token
    function ownerOf(uint256 id) public view virtual returns (address owner) {
        owner = _ownerOf[id];

        if (owner == address(0)) {
            revert NotFound();
        }
    }

    /// @notice tokenURI must be implemented by child contract
    function tokenURI(uint256 id) public view virtual returns (string memory);

    /// @notice Function for token approvals
    /// @dev This function assumes id / native if amount less than or equal to current max id
    function approve(
        address spender,
        uint256 amountOrId
    ) public virtual returns (bool) {
        if (amountOrId <= minted && amountOrId > 0) {
            address owner = _ownerOf[amountOrId];

            if (msg.sender != owner && !isApprovedForAll[owner][msg.sender]) {
                revert Unauthorized();
            }

            getApproved[amountOrId] = spender;

            emit Approval(owner, spender, amountOrId);
        } else {
            allowance[msg.sender][spender] = amountOrId;

            emit Approval(msg.sender, spender, amountOrId);
        }

        return true;
    }

    /// @notice Function native approvals
    function setApprovalForAll(address operator, bool approved) public virtual {
        // Prevent approvals to 0x0.
        if (operator == address(0)) {
            revert InvalidOperator();
        }
        isApprovedForAll[msg.sender][operator] = approved;

        emit ApprovalForAll(msg.sender, operator, approved);
    }

    /// @notice Function for mixed transfers
    /// @dev This function assumes id / native if amount less than or equal to current max id
    function transferFrom(
        address from,
        address to,
        uint256 amountOrId
    ) public virtual {
        if (amountOrId <= minted) {
            if (from != _ownerOf[amountOrId]) {
                revert InvalidSender();
            }

            if (to == address(0)) {
                revert InvalidRecipient();
            }

            if (
                msg.sender != from &&
                !isApprovedForAll[from][msg.sender] &&
                msg.sender != getApproved[amountOrId]
            ) {
                revert Unauthorized();
            }

            require(balanceOf[from] >= _getUnit());
            balanceOf[from] -= _getUnit();

            unchecked {
                balanceOf[to] += _getUnit();
            }

            _ownerOf[amountOrId] = to;
            delete getApproved[amountOrId];

            TexasPoker.HandRank rank = _rank[amountOrId];
            // update _owned for sender
            uint256 updatedId = _owned[from][rank][
                _owned[from][rank].length - 1
            ];
            _owned[from][rank][_ownedIndex[amountOrId]] = updatedId;
            // pop
            _owned[from][rank].pop();
            // update index for the moved id
            _ownedIndex[updatedId] = _ownedIndex[amountOrId];
            // push token to to owned
            _owned[to][rank].push(amountOrId);
            require(_owned[to][rank].length > 0);
            // update index for to owned
            _ownedIndex[amountOrId] = _owned[to][rank].length - 1;
            require(nftBalanceOf[from] > 0);
            nftBalanceOf[from] = nftBalanceOf[from] - 1;
            nftBalanceOf[to] = nftBalanceOf[to] + 1;

            if (to == address(this)) {
                stakingOwner[amountOrId] = from;
            } else if (from == address(this)) {
                delete stakingOwner[amountOrId];
            }

            emit Transfer(from, to, amountOrId);
            evSend(from, to, _getUnit());
        } else {
            uint256 allowed = allowance[from][msg.sender];
            require(allowed >= amountOrId);

            if (allowed != type(uint256).max)
                allowance[from][msg.sender] = allowed - amountOrId;

            _transfer(from, to, amountOrId);
        }
    }

    /// @notice Function for fractional transfers
    function transfer(
        address to,
        uint256 amount
    ) public virtual returns (bool) {
        return _transfer(msg.sender, to, amount);
    }

    /// @notice Function for native transfers with contract support
    function safeTransferFrom(
        address from,
        address to,
        uint256 id
    ) public virtual {
        transferFrom(from, to, id);

        if (
            to.code.length != 0 &&
            ERC721Receiver(to).onERC721Received(msg.sender, from, id, "") !=
            ERC721Receiver.onERC721Received.selector
        ) {
            revert UnsafeRecipient();
        }
    }

    /// @notice Function for native transfers with contract support and callback data
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        bytes calldata data
    ) public virtual {
        transferFrom(from, to, id);

        if (
            to.code.length != 0 &&
            ERC721Receiver(to).onERC721Received(msg.sender, from, id, data) !=
            ERC721Receiver.onERC721Received.selector
        ) {
            revert UnsafeRecipient();
        }
    }

    /// @notice Internal function for fractional transfers
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal returns (bool) {
        uint256 unit = _getUnit();

        require(balanceOf[from] >= amount);
        balanceOf[from] -= amount;

        unchecked {
            balanceOf[to] += amount;
        }

        for (uint256 i = balanceOf[from] / unit; i < nftBalanceOf[from]; i++) {
            _burn(from);
        }

        evSend(from, to, amount);
        return true;
    }

    // Internal utility logic
    function _getUnit() internal view returns (uint256) {
        return 10 ** decimals;
    }

    function staking(uint256[] memory ids) public virtual{
        for (uint i = 0; i < ids.length; i++) {
            require(ownerOf(ids[i]) == msg.sender);
            transferFrom(msg.sender, address(this), ids[i]);
        }
    }

    function unstaking(uint256[] memory ids) public virtual{
        for (uint i = 0; i < ids.length; i++) {
            require(stakingOwner[ids[i]] == msg.sender);
            IERC721(address(this)).transferFrom(address(this), msg.sender, ids[i]);
        }
    }

    function stakingByRank(TexasPoker.HandRank[] memory ranks) public virtual {
        
        for (uint i = 0; i < ranks.length; i++) {
            TexasPoker.HandRank rank = ranks[i];
            uint256 num = _owned[msg.sender][rank].length;

            for (uint j = 0; j < num; j++) {
                uint256 id = _owned[msg.sender][rank][_owned[msg.sender][rank].length - 1];
                require(ownerOf(id) == msg.sender);
                transferFrom(msg.sender, address(this), id);
            }
        }
    }

    function remint(uint256 number) public virtual returns (uint256) {
        uint256 unit = _getUnit();
        require(nftBalanceOf[msg.sender] > 0);
        require(number > 0);
        require(balanceOf[msg.sender] >= (mintFee + unit) * number);

        // Gather Fees enough fees
        for (; (balanceOf[msg.sender] - unit * nftBalanceOf[msg.sender]) < mintFee * number; ) {
            _burn(msg.sender);
        }

        for (uint i = 0; i < number; i++) {
            // require(balanceOf[msg.sender] >= mintFee + unit);
            balanceOf[msg.sender] -= mintFee;
            balanceOf[_reward] += mintFee;
            _burn(msg.sender);
            _mint(msg.sender);
        }
        
        evSend(msg.sender, _reward, mintFee * number);
        return number;
    }

    function mint(uint256 number) public virtual returns (uint256) {
        require(number > 0);
        require(balanceOf[msg.sender] > 1);
        uint256 unit = _getUnit();
        uint i = 0;
        for (; i < number; i++) {
            if (
                (balanceOf[msg.sender] - mintFee) / unit <=
                nftBalanceOf[msg.sender]
            ) {
                break;
            }

            balanceOf[msg.sender] -= mintFee;
            balanceOf[_reward] += mintFee;

            _mint(msg.sender);
        }

        if (i > 0) {
            evSend(msg.sender, _reward, mintFee * i);
        }
        return i;
    }

    function _mint(address to) internal virtual {
        if (to == address(0)) {
            revert InvalidRecipient();
        }

        unchecked {
            minted++;
        }

        uint256 id = minted;

        if (_ownerOf[id] != address(0)) {
            revert AlreadyExists();
        }

        bytes32 blockHash = blockhash(block.number);

        bytes32 mixed = keccak256(
            abi.encodePacked(blockHash, msg.sender, minted)
        );
        uint256 rand = uint256(mixed);

        TexasPoker.Card[5] memory cards = TexasPoker.convertToTexasPoker(rand);

        TexasPoker.HandRank rank = TexasPoker.evaluateHand(cards);

        _ownerOf[id] = to;
        _owned[to][rank].push(id);
        _ownedIndex[id] = _owned[to][rank].length - 1;
        _rank[id] = rank;
        card[id] = TexasPoker.card2uint(cards);
        nftBalanceOf[to] = nftBalanceOf[to] + 1;

        emit Transfer(address(0), to, id);
    }

    function _burn(address from) internal virtual {
        if (from == address(0)) {
            revert InvalidSender();
        }
        require(nftBalanceOf[from] > 0);

        for (
            uint256 i = uint256(TexasPoker.HandRank.HighCard);
            i <= uint256(TexasPoker.HandRank.RoyalFlush);
            i++
        ) {
            TexasPoker.HandRank rank = TexasPoker.HandRank(i);
            uint256 num = _owned[from][rank].length;
            if (num == 0) {
                continue;
            }

            uint256 id = _owned[from][rank][_owned[from][rank].length - 1];
            _owned[from][rank].pop();
            delete _ownedIndex[id];
            delete _ownerOf[id];
            delete getApproved[id];
            delete card[id];
            delete _rank[id];
            nftBalanceOf[from] = nftBalanceOf[from] - 1;

            emit Transfer(from, address(0), id);
            return;
        }
    }


    function setRewardContract(address newAddr) public onlyOwner{
        _reward = newAddr;
    }

    function setMintFee(uint256 newFee)public onlyOwner{
        mintFee = newFee;
    }

    function rewardAddr() public view virtual returns (address) {
        return _reward;
    }

    function getNFTList(address user,TexasPoker.HandRank rank) public view virtual returns (uint256[] memory) {
        return _owned[user][rank];
    }

    function getCards(uint256 id) public view virtual returns (string memory) {
        return TexasPoker.uint2UnicodeStr(card[id]);
    }
}
