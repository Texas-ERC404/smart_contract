// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "@openzeppelin/contracts/utils/Strings.sol";

library TexasPoker {
    enum Suit {
        Hearts,
        Diamonds,
        Clubs,
        Spades
    }

    struct Card {
        Suit suit;
        uint8 rank;
    }

    enum HandRank {
        HighCard,
        OnePair,
        TwoPairs,
        ThreeOfAKind,
        Straight,
        Flush,
        FullHouse,
        FourOfAKind,
        StraightFlush,
        RoyalFlush
    }

    function convertToTexasPoker(
        uint256 bigInteger
    ) external pure returns (Card[5] memory) {
        Card[5] memory cards;
        uint256[] memory deck = new uint256[](52);

        for (uint256 i = 0; i < 52; i++) {
            deck[i] = i;
        }

        for (uint256 j = 0; j < 5; j++) {
            uint256 index = bigInteger % (52 - j);
            uint256 num = deck[index];
            cards[j].suit = Suit(num % 4);
            cards[j].rank = uint8(num % 13);
            deck[index] = deck[51 - j];
            bigInteger = bigInteger / (52 - j);
        }

        return cards;
    }

    function evaluateHand(
        Card[5] memory cards
    ) external pure returns (HandRank) {
        sort(cards);

        if (isRoyalFlush(cards)) {
            return HandRank.RoyalFlush;
        } else if (isStraightFlush(cards)) {
            return HandRank.StraightFlush;
        } else if (isFourOfAKind(cards)) {
            return HandRank.FourOfAKind;
        } else if (isFullHouse(cards)) {
            return HandRank.FullHouse;
        } else if (isFlush(cards)) {
            return HandRank.Flush;
        } else if (isStraight(cards)) {
            return HandRank.Straight;
        } else if (isThreeOfAKind(cards)) {
            return HandRank.ThreeOfAKind;
        } else if (isTwoPairs(cards)) {
            return HandRank.TwoPairs;
        } else if (isOnePair(cards)) {
            return HandRank.OnePair;
        } else {
            return HandRank.HighCard;
        }
    }

    function isRoyalFlush(Card[5] memory cards) internal pure returns (bool) {
        return
            isStraightFlush(cards) && cards[0].rank == 0 && cards[4].rank == 12;
    }

    function isStraightFlush(
        Card[5] memory cards
    ) internal pure returns (bool) {
        return isStraight(cards) && isFlush(cards);
    }

    function isFourOfAKind(Card[5] memory cards) internal pure returns (bool) {
        return
            (cards[0].rank == cards[1].rank &&
                cards[1].rank == cards[2].rank &&
                cards[2].rank == cards[3].rank) ||
            (cards[1].rank == cards[2].rank &&
                cards[2].rank == cards[3].rank &&
                cards[3].rank == cards[4].rank);
    }

    function isFullHouse(Card[5] memory cards) internal pure returns (bool) {
        return
            (cards[0].rank == cards[1].rank &&
                cards[1].rank == cards[2].rank &&
                cards[3].rank == cards[4].rank) ||
            (cards[0].rank == cards[1].rank &&
                cards[2].rank == cards[3].rank &&
                cards[3].rank == cards[4].rank);
    }

    function isFlush(Card[5] memory cards) internal pure returns (bool) {
        for (uint256 i = 1; i < 5; i++) {
            if (cards[i].suit != cards[0].suit) {
                return false;
            }
        }
        return true;
    }

    function isStraight(Card[5] memory cards) internal pure returns (bool) {
        if (
            cards[0].rank == 0 &&
            cards[1].rank == 9 &&
            cards[2].rank == 10 &&
            cards[3].rank == 11 &&
            cards[4].rank == 12
        ) {
            return true;
        }
        for (uint256 i = 1; i < 5; i++) {
            if (cards[i].rank != cards[i - 1].rank + 1) {
                return false;
            }
        }
        return true;
    }

    function isThreeOfAKind(Card[5] memory cards) internal pure returns (bool) {
        return
            (cards[0].rank == cards[1].rank &&
                cards[1].rank == cards[2].rank) ||
            (cards[1].rank == cards[2].rank &&
                cards[2].rank == cards[3].rank) ||
            (cards[2].rank == cards[3].rank && cards[3].rank == cards[4].rank);
    }

    function isTwoPairs(Card[5] memory cards) internal pure returns (bool) {
        return
            (cards[0].rank == cards[1].rank &&
                cards[2].rank == cards[3].rank) ||
            (cards[0].rank == cards[1].rank &&
                cards[3].rank == cards[4].rank) ||
            (cards[1].rank == cards[2].rank && cards[3].rank == cards[4].rank);
    }

    function isOnePair(Card[5] memory cards) internal pure returns (bool) {
        for (uint256 i = 0; i < 4; i++) {
            if (cards[i].rank == cards[i + 1].rank) {
                return true;
            }
        }
        return false;
    }

    function sort(Card[5] memory arr) internal pure {
        for (uint256 i = 0; i < arr.length; i++) {
            for (uint256 j = i + 1; j < arr.length; j++) {
                if (arr[i].rank > arr[j].rank) {
                    Card memory temp = arr[i];
                    arr[i] = arr[j];
                    arr[j] = temp;
                } else if (
                    arr[i].rank == arr[j].rank && arr[i].suit > arr[j].suit
                ) {
                    Card memory temp = arr[i];
                    arr[i] = arr[j];
                    arr[j] = temp;
                }
            }
        }
    }

    function card2uint(Card[5] memory arr) public pure returns (uint) {
        uint out;
        for (uint i = 0; i < 5; i++) {
            out = out * 52;
            out = out + uint(arr[i].suit) * 4 + uint(arr[i].rank);
        }
        return out;
    }

    function uint2str(uint val) public pure returns (string memory) {
        string memory out;
        for (uint i = 0; i < 5; i++) {
            uint r = val % 52;
            val = val / 52;
            out = string.concat(
                out,
                Strings.toHexString(r / 4),
                Strings.toHexString((r % 13) + 2)
            );
        }

        return out;
    }
}
