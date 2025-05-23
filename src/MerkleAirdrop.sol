// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Token} from "src/Token.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract MerkleAirdrop is EIP712 {
    using SafeERC20 for IERC20;
    // Some list of address
    // Allow someone in the list to claim tokens

    error MerkleAirdrop__InvalidProof();
    error MerkleAirdrop__AlreadyClaimed();
    error MerkleAirdrop__InvalidSignature();

    event Claim(address account, uint256 amount);

    address[] claimers;
    bytes32 private immutable i_merkleRoot;
    IERC20 private immutable i_airdropToken;
    bytes32 private constant MESSAGE_TYPEHASH = keccak256("AirdropClaim(address,uint256)");
    address public actualSigner;

    struct AirdropClaim {
        address account;
        uint256 amount;
    }

    mapping(address claimer => bool claimed) private s_hasClaimed;

    constructor(bytes32 merkleRoot, IERC20 airdropToken) EIP712("MerkleAirdrop", "1") {
        i_merkleRoot = merkleRoot;
        i_airdropToken = airdropToken;
    }

    /* 
    @param account address of the claimer
    @param amount amount of tokens to claim
    @param merkleProof merkle proof
    @note in merkle proof, hashing must be done twice using keccak256
    even though the chance of collision is very slim to happen, double 
    hashing 99% make sure that the collision will not happen
     */
    function claim(address account, uint256 amount, bytes32[] calldata merkleProof, uint8 v, bytes32 r, bytes32 s)
        external
    {
        if (s_hasClaimed[account]) {
            revert MerkleAirdrop__AlreadyClaimed();
        }

        if (!_isValidSignature(account, getMessageHash(account, amount), v, r, s)) {
            revert MerkleAirdrop__InvalidSignature();
        }

        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(account, amount))));
        if (!MerkleProof.verify(merkleProof, i_merkleRoot, leaf)) {
            revert MerkleAirdrop__InvalidProof();
        }

        s_hasClaimed[account] = true;
        emit Claim(account, amount);
        i_airdropToken.safeTransfer(account, amount);
    }

    /* 
    @param digest is a hashed message
     */
    function _isValidSignature(address account, bytes32 digest, uint8 v, bytes32 r, bytes32 s)
        internal
        returns (bool)
    {
        (actualSigner,,) = ECDSA.tryRecover(digest, v, r, s);
        return actualSigner == account;
    }

    function getMessageHash(address account, uint256 amount) public view returns (bytes32) {
        return
            _hashTypedDataV4(keccak256(abi.encode(MESSAGE_TYPEHASH, AirdropClaim({account: account, amount: amount}))));
    }

    function getMerkleRoot() external view returns (bytes32) {
        return i_merkleRoot;
    }

    function getAirdropToken() external view returns (IERC20) {
        return i_airdropToken;
    }

    function getActualSigner() external view returns (address) {
        return actualSigner;
    }
}
