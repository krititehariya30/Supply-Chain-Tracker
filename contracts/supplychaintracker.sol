// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract SupplyChainTracker {
    enum ProductState {
        Created,
        InTransit,
        Delivered,
        Verified
    }
    
    struct Product {
        uint256 id;
        string name;
        string description;
        address manufacturer;
        address currentOwner;
        ProductState state;
        uint256 createdAt;
        uint256 lastUpdated;
        bool isAuthentic;
    }
    
    struct TrackingEvent {
        uint256 productId;
        address actor;
        ProductState newState;
        string location;
        uint256 timestamp;
        string notes;
    }
    
    mapping(uint256 => Product) public products;
    mapping(uint256 => TrackingEvent[]) public productHistory;
    mapping(address => bool) public authorizedActors;
    mapping(uint256 => bool) public productExists;
    
    uint256 public productCounter;
    address public admin;
    
    event ProductCreated(
        uint256 indexed productId,
        string name,
        address indexed manufacturer
    );
    
    event ProductStateChanged(
        uint256 indexed productId,
        ProductState newState,
        address indexed actor,
        string location
    );
    
    event OwnershipTransferred(
        uint256 indexed productId,
        address indexed previousOwner,
        address indexed newOwner
    );
    
    event ActorAuthorized(address indexed actor);
    event ActorRevoked(address indexed actor);
    
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }
    
    modifier onlyAuthorized() {
        require(authorizedActors[msg.sender] || msg.sender == admin, "Not authorized");
        _;
    }
    
    modifier productValid(uint256 _productId) {
        require(productExists[_productId], "Product does not exist");
        _;
    }
    
    constructor() {
        admin = msg.sender;
        authorizedActors[msg.sender] = true;
    }
    
    function createProduct(
        string memory _name,
        string memory _description,
        address _manufacturer
    ) external onlyAuthorized {
        require(bytes(_name).length > 0, "Product name cannot be empty");
        require(_manufacturer != address(0), "Invalid manufacturer address");
        
        uint256 productId = productCounter;
        
        products[productId] = Product({
            id: productId,
            name: _name,
            description: _description,
            manufacturer: _manufacturer,
            currentOwner: _manufacturer,
            state: ProductState.Created,
            createdAt: block.timestamp,
            lastUpdated: block.timestamp,
            isAuthentic: true
        });
        
        productExists[productId] = true;
        
        // Add initial tracking event
        productHistory[productId].push(TrackingEvent({
            productId: productId,
            actor: msg.sender,
            newState: ProductState.Created,
            location: "Manufacturing Facility",
            timestamp: block.timestamp,
            notes: "Product created and registered"
        }));
        
        emit ProductCreated(productId, _name, _manufacturer);
        productCounter++;
    }
    
    function updateProductState(
        uint256 _productId,
        ProductState _newState,
        string memory _location,
        string memory _notes
    ) external onlyAuthorized productValid(_productId) {
        Product storage product = products[_productId];
        
        require(_newState != product.state, "State is already current");
        require(_isValidStateTransition(product.state, _newState), "Invalid state transition");
        
        product.state = _newState;
        product.lastUpdated = block.timestamp;
        
        productHistory[_productId].push(TrackingEvent({
            productId: _productId,
            actor: msg.sender,
            newState: _newState,
            location: _location,
            timestamp: block.timestamp,
            notes: _notes
        }));
        
        emit ProductStateChanged(_productId, _newState, msg.sender, _location);
    }
    
    function transferOwnership(
        uint256 _productId,
        address _newOwner
    ) external onlyAuthorized productValid(_productId) {
        require(_newOwner != address(0), "Invalid new owner address");
        
        Product storage product = products[_productId];
        address previousOwner = product.currentOwner;
        
        require(previousOwner != _newOwner, "Already the current owner");
        
        product.currentOwner = _newOwner;
        product.lastUpdated = block.timestamp;
        
        productHistory[_productId].push(TrackingEvent({
            productId: _productId,
            actor: msg.sender,
            newState: product.state,
            location: "Ownership Transfer",
            timestamp: block.timestamp,
            notes: string(abi.encodePacked("Ownership transferred from ", _addressToString(previousOwner), " to ", _addressToString(_newOwner)))
        }));
        
        emit OwnershipTransferred(_productId, previousOwner, _newOwner);
    }
    
    function verifyAuthenticity(uint256 _productId) 
        external 
        view 
        productValid(_productId) 
        returns (bool) {
        return products[_productId].isAuthentic;
    }
    
    function getProductHistory(uint256 _productId) 
        external 
        view 
        productValid(_productId) 
        returns (TrackingEvent[] memory) {
        return productHistory[_productId];
    }
    
    function authorizeActor(address _actor) external onlyAdmin {
        require(_actor != address(0), "Invalid actor address");
        require(!authorizedActors[_actor], "Actor already authorized");
        
        authorizedActors[_actor] = true;
        emit ActorAuthorized(_actor);
    }
    
    function revokeActor(address _actor) external onlyAdmin {
        require(_actor != address(0), "Invalid actor address");
        require(_actor != admin, "Cannot revoke admin");
        require(authorizedActors[_actor], "Actor not authorized");
        
        authorizedActors[_actor] = false;
        emit ActorRevoked(_actor);
    }
    
    function _isValidStateTransition(ProductState _current, ProductState _new) 
        internal 
        pure 
        returns (bool) {
        if (_current == ProductState.Created && _new == ProductState.InTransit) return true;
        if (_current == ProductState.InTransit && _new == ProductState.Delivered) return true;
        if (_current == ProductState.Delivered && _new == ProductState.Verified) return true;
        return false;
    }
    
    function _addressToString(address _addr) internal pure returns (string memory) {
        bytes32 value = bytes32(uint256(uint160(_addr)));
        bytes memory alphabet = "0123456789abcdef";
        bytes memory str = new bytes(42);
        str[0] = '0';
        str[1] = 'x';
        for (uint256 i = 0; i < 20; i++) {
            str[2+i*2] = alphabet[uint8(value[i + 12] >> 4)];
            str[3+i*2] = alphabet[uint8(value[i + 12] & 0x0f)];
        }
        return string(str);
    }
}
