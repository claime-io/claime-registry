// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import "./interfaces/IClaimRegistry.sol";
import "hardhat/console.sol";

/// @title Claimer - manages the posted items and donation flows.
/// @author Shoya Yanagisawa - <shoya.yanagisawa@bridges.inc>
contract ClaimRegistry is IClaimRegistry {
	/// @dev Maps address with the claimKeys.
	mapping(address => uint256[]) public allClaimKeys;

	/// @dev Maps claimKey<uint256: hash of address, propertyType, propertyId, method> with the claim.
	mapping(uint256 => Claim) public allClaims;

	/// @dev Maps address with the claim registry.
	mapping(address => ClaimRef) public allClaimRefs;

	/// @inheritdoc IClaimRegistry
	function register(
		string memory propertyType,
		string memory propertyId,
		string memory evidence,
		string memory method
	) public override {
		require(!_isEmptyStr(propertyType), "CLM001");
		require(!_isEmptyStr(propertyId), "CLM002");
		uint256 claimKey = _toClaimKey(
			msg.sender,
			propertyType,
			propertyId,
			method
		);
		bool isNew = _isEmptyStr(allClaims[claimKey].propertyType);
		allClaims[claimKey].propertyType = propertyType;
		allClaims[claimKey].propertyId = propertyId;
		allClaims[claimKey].evidence = evidence;
		allClaims[claimKey].method = method;
		if (isNew) {
			allClaimKeys[msg.sender].push(claimKey);
		}
		emit ClaimUpdated(msg.sender, allClaims[claimKey]);
	}

	/// @inheritdoc IClaimRegistry
	function registerRef(string memory ref, string memory key) public override {
		allClaimRefs[msg.sender].ref = ref;
		allClaimRefs[msg.sender].key = key;
		if (_isEmptyStr(ref) && _isEmptyStr(key)) {
			emit ClaimRefRemoved(msg.sender);
		} else {
			emit ClaimRefUpdated(msg.sender, allClaimRefs[msg.sender]);
		}
	}

	/// @inheritdoc IClaimRegistry
	function remove(
		string memory propertyType,
		string memory propertyId,
		string memory method
	) public override {
		require(!_isEmptyStr(propertyType), "CLM001");
		require(!_isEmptyStr(propertyId), "CLM002");
		uint256 claimKey = _toClaimKey(
			msg.sender,
			propertyType,
			propertyId,
			method
		);
		uint256 keysLength = allClaimKeys[msg.sender].length;
		uint256 index = keysLength;
		for (uint256 i = 0; i < keysLength; i++) {
			if (allClaimKeys[msg.sender][i] == claimKey) {
				index = i;
				break;
			}
		}
		if (index < keysLength) {
			delete allClaims[claimKey];
			allClaimKeys[msg.sender][index] = allClaimKeys[msg.sender][
				keysLength - 1
			];
			allClaimKeys[msg.sender].pop();
			emit ClaimRemoved(msg.sender, propertyType, propertyId);
		}
	}

	/// @inheritdoc IClaimRegistry
	function removeRef() public override {
		registerRef("", "");
	}

	/// @inheritdoc IClaimRegistry
	function listClaims(address account)
		public
		view
		override
		returns (uint256[] memory, string[2] memory)
	{
		return (
			allClaimKeys[account],
			[allClaimRefs[account].ref, allClaimRefs[account].key]
		);
	}

	function _equalsStr(string memory a, string memory b)
		internal
		pure
		returns (bool)
	{
		if (bytes(a).length != bytes(b).length) {
			return false;
		} else {
			return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
		}
	}

	function _isEmptyStr(string memory a) internal pure returns (bool) {
		return _equalsStr(a, "");
	}

	function _toClaimKey(
		address account,
		string memory propertyType,
		string memory propertyId,
		string memory method
	) internal pure returns (uint256) {
		return
			uint256(
				keccak256(abi.encodePacked(account, propertyType, propertyId, method))
			);
	}
}