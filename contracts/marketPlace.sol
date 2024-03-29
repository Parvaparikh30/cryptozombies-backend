pragma solidity ^0.8;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
// import "./zombieownership.sol";

contract Marketplace is ReentrancyGuard {
    using Counters for Counters.Counter;

    Counters.Counter private _marketItemIds;
    Counters.Counter private _tokensSold;
    Counters.Counter private _tokensCanceled;

    address payable private owner;
    uint256 private listingFee = 0.045 ether;

    mapping(uint256 => MarketItem) public marketItemIdToMarketItem;


struct MarketItem {
        uint256 marketItemId;
        address nftContractAddress;
        uint256 tokenId;
        address payable seller;
        address payable owner;
        uint256 price;
        bool sold;
        bool canceled;
    }

    event MarketItemCreated(
        uint256 indexed marketItemId,
        address indexed nftContract,
        uint256 indexed tokenId,
        address seller,
        address owner,
        uint256 price,
        bool sold,
        bool canceled
    );

       constructor() {
        owner = payable(msg.sender);
    }

      function getListingFee() public view returns (uint256) {
        return listingFee;
    }


//      function _transfer(address _from, address _to, uint256 _tokenId) private {
//     ownerZombieCount[_to] = ownerZombieCount[_to].add(1);
//     ownerZombieCount[msg.sender] = ownerZombieCount[msg.sender].sub(1);
//     zombieToOwner[_tokenId] = _to;
//     emit Transfer(_from, _to, _tokenId);
//   }

//   function transferFrom(address _from, address _to, uint256 _tokenId) external payable {
//       require (zombieToOwner[_tokenId] == msg.sender || zombieApprovals[_tokenId] == msg.sender);
//       _transfer(_from, _to, _tokenId);
//     }




      function createMarketItem(
        address nftContractAddress,
        uint256 tokenId,
        uint256 price
    ) public payable nonReentrant returns (uint256) {
        require(price > 0, "Price must be at least 1 wei");
        // require(msg.value == listingFee, "Price must be equal to listing price");
        _marketItemIds.increment();
        uint256 marketItemId = _marketItemIds.current();


        marketItemIdToMarketItem[marketItemId] = MarketItem(
            marketItemId,
            nftContractAddress,
            tokenId,
            payable(msg.sender),
            payable(address(0)),
            price,
            false,
            false
        );

        IERC721(nftContractAddress).transferFrom(msg.sender, address(this), tokenId);

        emit MarketItemCreated(
            marketItemId,
            nftContractAddress,
            tokenId,
            payable(msg.sender),
            payable(address(0)),
            price,
            false,
            false
        );

        

        return marketItemId;
    }

    function createMarketSale(address nftContractAddress, uint256 marketItemId) public payable nonReentrant {
        uint256 price = marketItemIdToMarketItem[marketItemId].price;
        uint256 tokenId = marketItemIdToMarketItem[marketItemId].tokenId;
        require(msg.value == price, "Please submit the asking price in order to continue");

        marketItemIdToMarketItem[marketItemId].owner = payable(msg.sender);
        marketItemIdToMarketItem[marketItemId].sold = true;

        marketItemIdToMarketItem[marketItemId].seller.transfer(msg.value);
        IERC721(nftContractAddress).transferFrom(address(this), msg.sender, tokenId);

        _tokensSold.increment();

        // payable(owner).transfer(listingFee);
    }


       function fetchAvailableMarketItems() public view returns (MarketItem[] memory) {
        uint256 itemsCount = _marketItemIds.current();
        uint256 soldItemsCount = _tokensSold.current();
        uint256 canceledItemsCount = _tokensCanceled.current();
        uint256 availableItemsCount = itemsCount - soldItemsCount - canceledItemsCount;
        MarketItem[] memory marketItems = new MarketItem[](availableItemsCount);

        uint256 currentIndex = 0;
        for (uint256 i = 0; i < itemsCount; i++) {
            // Is this refactor better than the original implementation?
            // https://github.com/dabit3/polygon-ethereum-nextjs-marketplace/blob/main/contracts/Market.sol#L111
            // If so, is it better to use memory or storage here?
            MarketItem memory item = marketItemIdToMarketItem[i + 1];
            if (item.owner != address(0)) continue;
            marketItems[currentIndex] = item;
            currentIndex += 1;
        }

        return marketItems;
    }


    function cancelMarketItem( address nftContractAddress,uint256 marketItemId) public payable nonReentrant {
        uint256 tokenId = marketItemIdToMarketItem[marketItemId].tokenId;
        require(tokenId > 0, "Market item has to exist");

        require(marketItemIdToMarketItem[marketItemId].seller == msg.sender, "You are not the seller");

        IERC721(nftContractAddress).transferFrom(address(this), msg.sender, tokenId);

        marketItemIdToMarketItem[marketItemId].owner = payable(msg.sender);
        marketItemIdToMarketItem[marketItemId].canceled = true;

        _tokensCanceled.increment();
    }


    function getLatestMarketItemByTokenId(uint256 tokenId) public view returns (MarketItem memory, bool) {
        uint256 itemsCount = _marketItemIds.current();

        for (uint256 i = itemsCount; i > 0; i--) {
            MarketItem memory item = marketItemIdToMarketItem[i];
            if (item.tokenId != tokenId) continue;
            return (item, true);
        }

        // What is the best practice for returning a "null" value in solidity?
        // Reverting does't seem to be the best approach as it would throw an error on frontend
        MarketItem memory emptyMarketItem;
        return (emptyMarketItem, false);
    }



    //not much of use



    //  function getMarketItemAddressByProperty(MarketItem memory item, string memory property)
    //     private
    //     pure
    //     returns (address)
    // {
    //     require(
    //         compareStrings(property, "seller") || compareStrings(property, "owner"),
    //         "Parameter must be 'seller' or 'owner'"
    //     );

    //     return compareStrings(property, "seller") ? item.seller : item.owner;
    // }

    // /**
    //  * @dev Fetch market items that are being listed by the msg.sender
    //  */
    // function fetchSellingMarketItems() public view returns (MarketItem[] memory) {
    //     return fetchMarketItemsByAddressProperty("seller");
    // }

    // /**
    //  * @dev Fetch market items that are owned by the msg.sender
    //  */
    // function fetchOwnedMarketItems() public view returns (MarketItem[] memory) {
    //     return fetchMarketItemsByAddressProperty("owner");
    // }

    // /**
    //  * @dev Fetches market items according to the its requested address property that
    //  * can be "owner" or "seller". The original implementations were two functions that were
    //  * almost the same, changing only a property access. This refactored version requires an
    //  * addional auxiliary function, but avoids repeating code.
    //  * See original: https://github.com/dabit3/polygon-ethereum-nextjs-marketplace/blob/main/contracts/Market.sol#L121
    //  */
    // function fetchMarketItemsByAddressProperty(string memory _addressProperty)
    //     public
    //     view
    //     returns (MarketItem[] memory)
    // {
    //     require(
    //         compareStrings(_addressProperty, "seller") || compareStrings(_addressProperty, "owner"),
    //         "Parameter must be 'seller' or 'owner'"
    //     );
    //     uint256 totalItemsCount = _marketItemIds.current();
    //     uint256 itemCount = 0;
    //     uint256 currentIndex = 0;

    //     for (uint256 i = 0; i < totalItemsCount; i++) {
    //         // Is it ok to assign this variable for better code legbility?
    //         // Is it better to use memory or storage in this case?
    //         MarketItem storage item = marketItemIdToMarketItem[i + 1];
    //         address addressPropertyValue = getMarketItemAddressByProperty(item, _addressProperty);
    //         if (addressPropertyValue != msg.sender) continue;
    //         itemCount += 1;
    //     }

    //     MarketItem[] memory items = new MarketItem[](itemCount);

    //     for (uint256 i = 0; i < totalItemsCount; i++) {
    //         // Is it ok to assign this variable for better code legbility?
    //         // Is it better to use memory or storage in this case?
    //         MarketItem storage item = marketItemIdToMarketItem[i + 1];
    //         address addressPropertyValue = getMarketItemAddressByProperty(item, _addressProperty);
    //         if (addressPropertyValue != msg.sender) continue;
    //         items[currentIndex] = item;
    //         currentIndex += 1;
    //     }

    //     return items;
    // }
}



