pragma solidity ^0.4.24;

import "./ERC721.sol";
import "./ERC721Metadata.sol";
import "./ERC721TokenReceiver.sol";
import "@0xcert/ethereum-utils/contracts/math/SafeMath.sol";
import "@0xcert/ethereum-utils/contracts/utils/SupportsInterface.sol";
import "@0xcert/ethereum-utils/contracts/utils/AddressUtils.sol";

/**
 * @dev Optional metadata implementation for ERC-721 non-fungible token standard.
 */
contract NFTokenMetadata is
  ERC721,
  ERC721Metadata,
  SupportsInterface
{
  using SafeMath for uint256;
  using AddressUtils for address;

  /**
   * @dev A descriptive name for a collection of NFTs.
   */
  string internal nftName;

  /**
   * @dev An abbreviated name for NFTs.
   */
  string internal nftSymbol;

  /**
   * @dev Mapping from NFT ID to metadata URI.
   */
  mapping (uint256 => string) internal idToUri;

  /**
   * @dev A mapping from NFT ID to the address that owns it.
   */
  mapping (uint256 => address) internal idToOwner;

  /**
   * @dev Mapping from NFT ID to approved address.
   */
  mapping (uint256 => address) internal idToApproval;

   /**
   * @dev Mapping from owner address to count of his tokens.
   */
  mapping (address => uint256) internal ownerToNFTokenCount;

  /**
   * @dev Mapping from owner address to mapping of operator addresses.
   */
  mapping (address => mapping (address => bool)) internal ownerToOperators;

  /**
   * @dev Magic value of a smart contract that can recieve NFT.
   * Equal to: bytes4(keccak256("onERC721Received(address,address,uint256,bytes)")).
   */
  bytes4 constant MAGIC_ON_ERC721_RECEIVED = 0x150b7a02;

  /**
   * @dev Emits when ownership of any NFT changes by any mechanism. This event emits when NFTs are
   * created (`from` == 0) and destroyed (`to` == 0). Exception: during contract creation, any
   * number of NFTs may be created and assigned without emitting Transfer. At the time of any
   * transfer, the approved address for that NFT (if any) is reset to none.
   * @param _from Sender of NFT (if address is zero address it indicates token creation).
   * @param _to Receiver of NFT (if address is zero address it indicates token destruction).
   * @param _tokenId The NFT that got transfered.
   */
  event Transfer(
    address indexed _from,
    address indexed _to,
    uint256 indexed _tokenId
  );

  /**
   * @dev This emits when the approved address for an NFT is changed or reaffirmed. The zero
   * address indicates there is no approved address. When a Transfer event emits, this also
   * indicates that the approved address for that NFT (if any) is reset to none.
   * @param _owner Owner of NFT.
   * @param _approved Address that we are approving.
   * @param _tokenId NFT which we are approving.
   */
  event Approval(
    address indexed _owner,
    address indexed _approved,
    uint256 indexed _tokenId
  );

  /**
   * @dev This emits when an operator is enabled or disabled for an owner. The operator can manage
   * all NFTs of the owner.
   * @param _owner Owner of NFT.
   * @param _operator Address to which we are setting operator rights.
   * @param _approved Status of operator rights(true if operator rights are given and false if
   * revoked).
   */
  event ApprovalForAll(
    address indexed _owner,
    address indexed _operator,
    bool _approved
  );

  /**
   * @dev Contract constructor.
   * @notice When implementing this contract don't forget to set nftName and nftSymbol.
   */
  constructor()
    public
  {
    supportedInterfaces[0x80ac58cd] = true; // ERC721
    supportedInterfaces[0x5b5e139f] = true; // ERC721Metadata
  }

  /**
   * @dev Returns the number of NFTs owned by `_owner`. NFTs assigned to the zero address are
   * considered invalid, and this function throws for queries about the zero address.
   * @param _owner Address for whom to query the balance.
   */
  function balanceOf(
    address _owner
  )
    external
    view
    returns (uint256)
  {
    require(_owner != address(0));
    return ownerToNFTokenCount[_owner];
  }

  /**
   * @dev Returns the address of the owner of the NFT. NFTs assigned to zero address are considered
   * invalid, and queries about them do throw.
   * @param _tokenId The identifier for an NFT.
   */
  function ownerOf(
    uint256 _tokenId
  )
    external
    view
    returns (address _owner)
  {
    _owner = idToOwner[_tokenId];
    require(_owner != address(0));
  }

  /**
   * @dev Transfers the ownership of an NFT from one address to another address.
   * @notice Throws unless `msg.sender` is the current owner, an authorized operator, or the
   * approved address for this NFT. Throws if `_from` is not the current owner. Throws if `_to` is
   * the zero address. Throws if `_tokenId` is not a valid NFT. When transfer is complete, this
   * function checks if `_to` is a smart contract (code size > 0). If so, it calls 
   * `onERC721Received` on `_to` and throws if the return value is not 
   * `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`.
   * @param _from The current owner of the NFT.
   * @param _to The new owner.
   * @param _tokenId The NFT to transfer.
   * @param _data Additional data with no specified format, sent in call to `_to`.
   */
  function safeTransferFrom(
    address _from,
    address _to,
    uint256 _tokenId,
    bytes _data
  )
    external
  {
    _safeTransferFrom(_from, _to, _tokenId, _data);
  }

  /**
   * @dev Transfers the ownership of an NFT from one address to another address.
   * @notice This works identically to the other function with an extra data parameter, except this
   * function just sets data to "".
   * @param _from The current owner of the NFT.
   * @param _to The new owner.
   * @param _tokenId The NFT to transfer.
   */
  function safeTransferFrom(
    address _from,
    address _to,
    uint256 _tokenId
  )
    external
  {
    _safeTransferFrom(_from, _to, _tokenId, "");
  }

  /**
   * @dev Throws unless `msg.sender` is the current owner, an authorized operator, or the approved
   * address for this NFT. Throws if `_from` is not the current owner. Throws if `_to` is the zero
   * address. Throws if `_tokenId` is not a valid NFT.
   * @notice The caller is responsible to confirm that `_to` is capable of receiving NFTs or else
   * they maybe be permanently lost.
   * @param _from The current owner of the NFT.
   * @param _to The new owner.
   * @param _tokenId The NFT to transfer.
   */
  function transferFrom(
    address _from,
    address _to,
    uint256 _tokenId
  )
    external
  {
    _transferFrom(_from, _to, _tokenId);
  }

  /**
   * @dev Set or reaffirm the approved address for an NFT.
   * @notice The zero address indicates there is no approved address. Throws unless `msg.sender` is
   * the current NFT owner, or an authorized operator of the current owner.
   * @param _approved Address to be approved for the given NFT ID.
   * @param _tokenId ID of the token to be approved.
   */
  function approve(
    address _approved,
    uint256 _tokenId
  )
    external
  {
    // can operate
    address tokenOwner = idToOwner[_tokenId];
    require(tokenOwner == msg.sender || ownerToOperators[tokenOwner][msg.sender]);

    idToApproval[_tokenId] = _approved;
    emit Approval(tokenOwner, _approved, _tokenId);
  }

  /**
   * @dev Enables or disables approval for a third party ("operator") to manage all of
   * `msg.sender`'s assets. It also emits the ApprovalForAll event.
   * @notice This works even if sender doesn't own any tokens at the time.
   * @param _operator Address to add to the set of authorized operators.
   * @param _approved True if the operators is approved, false to revoke approval.
   */
  function setApprovalForAll(
    address _operator,
    bool _approved
  )
    external
  {
    ownerToOperators[msg.sender][_operator] = _approved;
    emit ApprovalForAll(msg.sender, _operator, _approved);
  }

  /**
   * @dev Get the approved address for a single NFT.
   * @notice Throws if `_tokenId` is not a valid NFT.
   * @param _tokenId ID of the NFT to query the approval of.
   */
  function getApproved(
    uint256 _tokenId
  )
    external
    view
    returns (address)
  {
    require(idToOwner[_tokenId] != address(0));
    return idToApproval[_tokenId];
  }

  /**
   * @dev Checks if `_operator` is an approved operator for `_owner`.
   * @param _owner The address that owns the NFTs.
   * @param _operator The address that acts on behalf of the owner.
   */
  function isApprovedForAll(
    address _owner,
    address _operator
  )
    external
    view
    returns (bool)
  {
    return ownerToOperators[_owner][_operator];
  }

  /**
   * @dev Returns a descriptive name for a collection of NFTs.
   */
  function name()
    external
    view
    returns (string _name)
  {
    _name = nftName;
  }

  /**
   * @dev Returns an abbreviated name for NFTs.
   */
  function symbol()
    external
    view
    returns (string _symbol)
  {
    _symbol = nftSymbol;
  }

  /**
   * @notice A distinct Uniform Resource Identifier (URI) for a given asset.
   * @dev Throws if `_tokenId` is not a valid NFT. URIs are defined in RFC 3986. The URI may point
   * to a JSON file that conforms to the "ERC721 Metadata JSON Schema".
   * @param _tokenId Id for which we want URI.
   */
  function tokenURI(
    uint256 _tokenId
  )
    external
    view
    returns (string)
  {
    require(idToOwner[_tokenId] != address(0));
    return idToUri[_tokenId];
  }

  /**
   * @dev Set a distinct URI (RFC 3986) for a given NFT ID.
   * @notice this is a internal function which should be called from user-implemented external
   * function. Its purpose is to show and properly initialize data structures when using this
   * implementation.
   * @param _tokenId Id for which we want URI.
   * @param _uri String representing RFC 3986 URI.
   */
  function _setTokenUri(
    uint256 _tokenId,
    string _uri
  )
    internal
  {
    require(idToOwner[_tokenId] != address(0));
    idToUri[_tokenId] = _uri;
  }

  /**
   * @dev Mints a new NFT.
   * @notice This is a private function which should be called from user-implemented external
   * mint function. Its purpose is to show and properly initialize data structures when using this
   * implementation.
   * @param _to The address that will own the minted NFT.
   * @param _tokenId of the NFT to be minted by the msg.sender.
   */
  function _mint(
    address _to,
    uint256 _tokenId,
    string _uri
  )
    internal
  {
    require(_to != address(0));
    require(idToOwner[_tokenId] == address(0));

    // add NFT
    idToOwner[_tokenId] = _to;
    idToUri[_tokenId] = _uri;
    ownerToNFTokenCount[_to] = ownerToNFTokenCount[_to].add(1);

    emit Transfer(address(0), _to, _tokenId);
  }

  /**
   * @dev Burns a NFT.
   * @notice This is a private function which should be called from user-implemented external
   * burn function. Its purpose is to show and properly initialize data structures when using this
   * implementation.
   * @param _tokenId ID of the NFT to be burned.
   */
  function _burn(
    uint256 _tokenId
  )
    internal
  {
    // valid NFT
    address owner = idToOwner[_tokenId];
    require(owner != address(0));

    // clear approval
    if(idToApproval[_tokenId] != 0)
    {
      delete idToApproval[_tokenId];
    }

    // remove NFT
    assert(ownerToNFTokenCount[owner] > 0);
    ownerToNFTokenCount[owner] = ownerToNFTokenCount[owner] - 1;
    delete idToOwner[_tokenId];

    // delete URI
    if (bytes(idToUri[_tokenId]).length != 0) {
      delete idToUri[_tokenId];
    }

    emit Transfer(owner, address(0), _tokenId);
  }

  /**
   * @dev Helper methods that actually does the transfer.
   * @param _from The current owner of the NFT.
   * @param _to The new owner.
   * @param _tokenId The NFT to transfer.
   */
  function _transferFrom(
    address _from,
    address _to,
    uint256 _tokenId
  )
    private
  {
    // valid NFT
    require(_from != address(0));
    require(idToOwner[_tokenId] == _from);
    require(_to != address(0));

    // can transfer
    require(
      _from == msg.sender
      || idToApproval[_tokenId] == msg.sender
      || ownerToOperators[_from][msg.sender]
    );

    // clear approval
    if(idToApproval[_tokenId] != 0)
    {
      delete idToApproval[_tokenId];
    }

    // remove NFT
    assert(ownerToNFTokenCount[_from] > 0);
    ownerToNFTokenCount[_from] = ownerToNFTokenCount[_from] - 1;

    // add NFT
    idToOwner[_tokenId] = _to;
    ownerToNFTokenCount[_to] = ownerToNFTokenCount[_to].add(1);

    emit Transfer(_from, _to, _tokenId);
  }

  /**
   * @dev Helper function that actually does the safeTransfer.
   * @param _from The current owner of the NFT.
   * @param _to The new owner.
   * @param _tokenId The NFT to transfer.
   * @param _data Additional data with no specified format, sent in call to `_to`.
   */
  function _safeTransferFrom(
    address _from,
    address _to,
    uint256 _tokenId,
    bytes _data
  )
    private
  {
    if (_to.isContract()) {
      require(
        ERC721TokenReceiver(_to)
          .onERC721Received(msg.sender, _from, _tokenId, _data) == MAGIC_ON_ERC721_RECEIVED
      );
    }

    _transferFrom(_from, _to, _tokenId);
  }
}