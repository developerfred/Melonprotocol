pragma solidity 0.6.4;

import "../dependencies/DSAuth.sol";
import "../fund/hub/ISpoke.sol";
import "../dependencies/token/IERC20.sol";

contract Registry is DSAuth {

    // EVENTS
    event AssetUpsert (
        address indexed asset,
        string name,
        string symbol,
        uint decimals,
        string url,
        uint reserveMin,
        uint[] standards,
        bytes4[] sigs
    );

    event ExchangeAdapterUpsert (
        address indexed exchange,
        address indexed adapter,
        bytes4[] sigs
    );

    event AssetRemoval (address indexed asset);
    event EngineChange(address indexed engine);
    event ExchangeAdapterRemoval (address indexed exchange);
    event IncentiveChange(uint incentiveAmount);
    event MGMChange(address indexed MGM);
    event MlnTokenChange(address indexed mlnToken);
    event NativeAssetChange(address indexed nativeAsset);
    event PriceSourceChange(address indexed priceSource);
    event FundFactoryRegistered(address indexed fundFactory);

    event SharesRequestorChanged(address sharesRequestor);

    // TYPES
    struct Asset {
        bool exists;
        string name;
        string symbol;
        uint decimals;
        string url;
        uint reserveMin;
        uint[] standards;
        bytes4[] sigs;
    }

    struct Exchange {
        bool exists;
        address exchangeAddress;
        bytes4[] sigs;
    }

    struct FundFactory {
        bool exists;
        bytes32 name;
    }

    // CONSTANTS
    uint public constant MAX_REGISTERED_ENTITIES = 20;
    uint public constant MAX_FUND_NAME_BYTES = 66;

    // FIELDS
    mapping (address => Asset) public assetInformation;
    address[] public registeredAssets;

    // Mapping from adapter address to exchange Information (Adapters are unique)
    mapping (address => Exchange) public exchangeInformation;
    address[] public registeredExchangeAdapters;

    mapping (address => FundFactory) public fundFactoryInformation;
    address[] public registeredFundFactories;

    mapping (address => bool) public isFeeRegistered;

    mapping (address => address) public fundsToFundFactories;
    mapping (bytes32 => bool) public fundFactoryNameExists;
    mapping (bytes32 => address) public fundNameHashToOwner;


    uint public incentive = 10 finney;
    address public priceSource;
    address public mlnToken;
    address public nativeAsset;
    address public engine;
    address public MGM;
    address public sharesRequestor;

    modifier onlyFundFactory() {
        require(
            fundFactoryInformation[msg.sender].exists,
            "Only a FundFactory can do this"
        );
        _;
    }

    // METHODS

    constructor(address _postDeployOwner) public {
        setOwner(_postDeployOwner);
    }

    // PUBLIC METHODS

    /// @notice Whether _name has only valid characters
    function isValidFundName(string memory _name) public pure returns (bool) {
        bytes memory b = bytes(_name);
        if (b.length > MAX_FUND_NAME_BYTES) return false;
        for (uint i; i < b.length; i++){
            bytes1 char = b[i];
            if(
                !(char >= 0x30 && char <= 0x39) && // 9-0
                !(char >= 0x41 && char <= 0x5A) && // A-Z
                !(char >= 0x61 && char <= 0x7A) && // a-z
                !(char == 0x20 || char == 0x2D) && // space, dash
                !(char == 0x2E || char == 0x5F) && // period, underscore
                !(char == 0x2A) // *
            ) {
                return false;
            }
        }
        return true;
    }

    /// @notice Whether _user can use _name for their fund
    function canUseFundName(address _user, string memory _name) public view returns (bool) {
        bytes32 nameHash = keccak256(bytes(_name));
        return (
            isValidFundName(_name) &&
            (
                fundNameHashToOwner[nameHash] == address(0) ||
                fundNameHashToOwner[nameHash] == _user
            )
        );
    }

    function reserveFundName(address _owner, string calldata _name)
        external
        onlyFundFactory
    {
        require(canUseFundName(_owner, _name), "Fund name cannot be used");
        fundNameHashToOwner[keccak256(bytes(_name))] = _owner;
    }

    function registerFund(address _fund, address _owner, string calldata _name)
        external
        onlyFundFactory
    {
        require(canUseFundName(_owner, _name), "Fund name cannot be used");
        fundsToFundFactories[_fund] = msg.sender;
    }

    /// @notice Registers an Asset information entry
    /// @dev Pre: Only registrar owner should be able to register
    /// @dev Post: Address _asset is registered
    /// @param _asset Address of asset to be registered
    /// @param _name Human-readable name of the Asset
    /// @param _symbol Human-readable symbol of the Asset
    /// @param _url Url for extended information of the asset
    /// @param _standards Integers of EIP standards this asset adheres to
    /// @param _sigs Function signatures for whitelisted asset functions
    function registerAsset(
        address _asset,
        string calldata _name,
        string calldata _symbol,
        string calldata _url,
        uint _reserveMin,
        uint[] calldata _standards,
        bytes4[] calldata _sigs
    ) external auth {
        require(registeredAssets.length < MAX_REGISTERED_ENTITIES);
        require(!assetInformation[_asset].exists);
        assetInformation[_asset].exists = true;
        registeredAssets.push(_asset);
        updateAsset(
            _asset,
            _name,
            _symbol,
            _url,
            _reserveMin,
            _standards,
            _sigs
        );
    }

    /// @notice Register an exchange information entry (A mapping from exchange adapter -> Exchange information)
    /// @dev Adapters are unique so are used as the mapping key. There may be different adapters for same exchange (0x / Ethfinex)
    /// @dev Pre: Only registrar owner should be able to register
    /// @dev Post: Address _exchange is registered
    /// @param _exchange Address of the exchange for the adapter
    /// @param _adapter Address of exchange adapter
    /// @param _sigs Function signatures for whitelisted exchange functions
    function registerExchangeAdapter(
        address _exchange,
        address _adapter,
        bytes4[] calldata _sigs
    ) external auth {
        require(!exchangeInformation[_adapter].exists, "Adapter already exists");
        exchangeInformation[_adapter].exists = true;
        require(registeredExchangeAdapters.length < MAX_REGISTERED_ENTITIES, "Exchange limit reached");
        registeredExchangeAdapters.push(_adapter);
        updateExchangeAdapter(
            _exchange,
            _adapter,
            _sigs
        );
    }

    /// @notice FundFactories cannot be removed from registry
    /// @param _fundFactory Address of the FundFactory contract
    /// @param _name Name of the fundFactory version
    function registerFundFactory(
        address _fundFactory,
        bytes32 _name
    ) external auth {
        require(!fundFactoryInformation[_fundFactory].exists, "FundFactory already exists");
        require(!fundFactoryNameExists[_name], "FundFactory name already exists");
        fundFactoryInformation[_fundFactory].exists = true;
        fundFactoryNameExists[_name] = true;
        fundFactoryInformation[_fundFactory].name = _name;
        registeredFundFactories.push(_fundFactory);
        emit FundFactoryRegistered(_fundFactory);
    }

    function setIncentive(uint _weiAmount) external auth {
        incentive = _weiAmount;
        emit IncentiveChange(_weiAmount);
    }

    function setPriceSource(address _priceSource) external auth {
        priceSource = _priceSource;
        emit PriceSourceChange(_priceSource);
    }

    function setMlnToken(address _mlnToken) external auth {
        mlnToken = _mlnToken;
        emit MlnTokenChange(_mlnToken);
    }

    function setNativeAsset(address _nativeAsset) external auth {
        nativeAsset = _nativeAsset;
        emit NativeAssetChange(_nativeAsset);
    }

    function setEngine(address _engine) external auth {
        engine = _engine;
        emit EngineChange(_engine);
    }

    function setMGM(address _MGM) external auth {
        MGM = _MGM;
        emit MGMChange(_MGM);
    }

    function setSharesRequestor(address _sharesRequestor) external auth {
        sharesRequestor = _sharesRequestor;
        emit SharesRequestorChanged(_sharesRequestor);
    }

    /// @notice Updates description information of a registered Asset
    /// @dev Pre: Owner can change an existing entry
    /// @dev Post: Changed Name, Symbol, URL and/or IPFSHash
    /// @param _asset Address of the asset to be updated
    /// @param _name Human-readable name of the Asset
    /// @param _symbol Human-readable symbol of the Asset
    /// @param _url Url for extended information of the asset
    function updateAsset(
        address _asset,
        string memory _name,
        string memory _symbol,
        string memory _url,
        uint _reserveMin,
        uint[] memory _standards,
        bytes4[] memory _sigs
    ) public auth {
        require(assetInformation[_asset].exists);
        Asset storage asset = assetInformation[_asset];
        asset.name = _name;
        asset.symbol = _symbol;
        asset.decimals = ERC20WithFields(_asset).decimals();
        asset.url = _url;
        asset.reserveMin = _reserveMin;
        asset.standards = _standards;
        asset.sigs = _sigs;
        emit AssetUpsert(
            _asset,
            _name,
            _symbol,
            asset.decimals,
            _url,
            _reserveMin,
            _standards,
            _sigs
        );
    }

    function updateExchangeAdapter(
        address _exchange,
        address _adapter,
        bytes4[] memory _sigs
    ) public auth {
        require(exchangeInformation[_adapter].exists, "Exchange with adapter doesn't exist");
        Exchange storage exchange = exchangeInformation[_adapter];
        exchange.exchangeAddress = _exchange;
        exchange.sigs = _sigs;
        emit ExchangeAdapterUpsert(
            _exchange,
            _adapter,
            _sigs
        );
    }

    /// @notice Deletes an existing entry
    /// @dev Owner can delete an existing entry
    /// @param _asset address for which specific information is requested
    function removeAsset(
        address _asset,
        uint _assetIndex
    ) external auth {
        require(assetInformation[_asset].exists);
        require(registeredAssets[_assetIndex] == _asset);
        delete assetInformation[_asset];
        delete registeredAssets[_assetIndex];
        for (uint i = _assetIndex; i < registeredAssets.length-1; i++) {
            registeredAssets[i] = registeredAssets[i+1];
        }
        registeredAssets.pop();
        emit AssetRemoval(_asset);
    }

    /// @notice Deletes an existing entry
    /// @dev Owner can delete an existing entry
    /// @param _adapter address of the adapter of the exchange that is to be removed
    /// @param _adapterIndex index of the exchange in array
    function removeExchangeAdapter(
        address _adapter,
        uint _adapterIndex
    ) external auth {
        require(exchangeInformation[_adapter].exists, "Exchange with adapter doesn't exist");
        require(registeredExchangeAdapters[_adapterIndex] == _adapter, "Incorrect adapter index");
        delete exchangeInformation[_adapter];
        delete registeredExchangeAdapters[_adapterIndex];
        for (uint i = _adapterIndex; i < registeredExchangeAdapters.length-1; i++) {
            registeredExchangeAdapters[i] = registeredExchangeAdapters[i+1];
        }
        registeredExchangeAdapters.pop();
        emit ExchangeAdapterRemoval(_adapter);
    }

    function registerFees(address[] calldata _fees) external auth {
        for (uint i; i < _fees.length; i++) {
            isFeeRegistered[_fees[i]] = true;
        }
    }

    function deregisterFees(address[] calldata _fees) external auth {
        for (uint i; i < _fees.length; i++) {
            delete isFeeRegistered[_fees[i]];
        }
    }

    // PUBLIC VIEW METHODS

    // get asset specific information
    function getName(address _asset) external view returns (string memory) {
        return assetInformation[_asset].name;
    }
    function getSymbol(address _asset) external view returns (string memory) {
        return assetInformation[_asset].symbol;
    }
    function getDecimals(address _asset) external view returns (uint) {
        return assetInformation[_asset].decimals;
    }
    function getReserveMin(address _asset) external view returns (uint) {
        return assetInformation[_asset].reserveMin;
    }
    function assetIsRegistered(address _asset) external view returns (bool) {
        return assetInformation[_asset].exists;
    }
    function getRegisteredAssets() external view returns (address[] memory) {
        return registeredAssets;
    }
    function assetMethodIsAllowed(address _asset, bytes4 _sig)
        external
        view
        returns (bool)
    {
        bytes4[] memory signatures = assetInformation[_asset].sigs;
        for (uint i = 0; i < signatures.length; i++) {
            if (signatures[i] == _sig) {
                return true;
            }
        }
        return false;
    }

    // get exchange-specific information
    function exchangeAdapterIsRegistered(address _adapter) external view returns (bool) {
        return exchangeInformation[_adapter].exists;
    }
    function getRegisteredExchangeAdapters() external view returns (address[] memory) {
        return registeredExchangeAdapters;
    }
    function exchangeForAdapter(address _adapter) external view returns (address) {
        Exchange memory exchange = exchangeInformation[_adapter];
        return exchange.exchangeAddress;
    }
    function getAdapterFunctionSignatures(address _adapter)
        public
        view
        returns (bytes4[] memory)
    {
        return exchangeInformation[_adapter].sigs;
    }
    function adapterMethodIsAllowed(
        address _adapter, bytes4 _sig
    )
        external
        view
        returns (bool)
    {
        bytes4[] memory signatures = exchangeInformation[_adapter].sigs;
        for (uint i = 0; i < signatures.length; i++) {
            if (signatures[i] == _sig) {
                return true;
            }
        }
        return false;
    }

    /// @notice get FundFactory and fund information
    function getRegisteredFundFactories() external view returns (address[] memory) {
        return registeredFundFactories;
    }

    function isFund(address _who) external view returns (bool) {
        // Check if hub
        if (isHub(_who)) return true;
        // Check if spoke
        else {
            // 1. Spoke points to hub
            // 2. Hub confirms it is a spoke
            // 3. Fund exists for hub
            try ISpoke(_who).hub() returns (IHub hub) {
                return hub.isSpoke(_who) && fundsToFundFactories[address(hub)] != address(0);
            }
            catch {
                return false;
            }
        }
    }

    function isFundFactory(address _who) external view returns (bool) {
        return fundFactoryInformation[_who].exists;
    }

    function isHub(address _who) public view returns (bool) {
        return fundsToFundFactories[_who] != address(0);
    }
}
