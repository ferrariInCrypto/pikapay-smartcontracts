// SPDX-License-Identifier: MIT

pragma solidity ^0.8.27;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./PikaFractionalAttestationToken.sol";
// import "./ZKPVerifier.sol";

contract PikaPay {
    using SafeERC20 for ERC20;

    struct Batch {
        uint256 batchId;
        PikaFractionalAttestationToken token;
        string attestationDetails;
        uint256 totalSupply;
        uint256 remainingSupply;
        bool isFinalized;
        address owner;
    }

    uint256 public totalBatches = 0;
    mapping(uint256 => Batch) public batchRegistry;
    mapping(uint256 => mapping(address => uint256)) public beneficiaryBalances;

    event BatchCreated(uint256 batchId, address indexed owner, string attestationDetails, uint256 totalAmount);
    event AttestedWithdrawal(uint256 batchId, address indexed beneficiary, uint256 amount, string attestation, string metadata);
    event BatchFinalized(uint256 batchId);
    event BatchUpdated(uint256 batchId, string updatedAttestationDetails);
    event OwnershipTransferred(uint256 batchId, address indexed previousOwner, address indexed newOwner, uint256 amount);

    ERC20 public token; // USDT Token address
    ZKPVerifier public zkpVerifier; // zk-SNARK verifier contract

    // Constructor accepts the ERC20 token address and the ZKP verifier address
    constructor(address _tokenAddress, address _zkpVerifierAddress) {
        token = ERC20(_tokenAddress);
        zkpVerifier = ZKPVerifier(_zkpVerifierAddress); // Initialize the verifier contract
    }

    modifier onlyBatchOwner(uint256 _batchId) {
        require(batchRegistry[_batchId].owner == msg.sender, "Caller is not the batch owner");
        _;
    }

    modifier validBatchId(uint256 _batchId) {
        require(_batchId > 0 && _batchId <= totalBatches, "Invalid batch ID");
        _;
    }

    function createNewBatchWithAttestation(string calldata _attestationDetails, uint256 _depositAmount) external {
        require(_depositAmount > 0, "Deposit amount must be greater than 0");

        totalBatches += 1;
        token.safeTransferFrom(msg.sender, address(this), _depositAmount);

        PikaFractionalAttestationToken fractionalToken = new PikaFractionalAttestationToken(this, totalBatches, _depositAmount);

        batchRegistry[totalBatches] = Batch({
            batchId: totalBatches,
            token: fractionalToken,
            attestationDetails: _attestationDetails,
            totalSupply: _depositAmount,
            remainingSupply: _depositAmount,
            isFinalized: false,
            owner: msg.sender
        });

        beneficiaryBalances[totalBatches][msg.sender] = _depositAmount;
        emit BatchCreated(totalBatches, msg.sender, _attestationDetails, _depositAmount);
    }

    function _transferBatchOwnership(
        uint256 _batchId,
        address _newOwner,
        uint256 _transferAmount,
        bytes memory _zkpProof,    // ZKP proof
        bytes memory _publicInputs  // Public inputs for verification
    ) internal {
        require(batchRegistry[_batchId].owner == msg.sender, "Caller is not the batch owner");
        require(_newOwner != address(0), "Invalid new owner address");
        require(beneficiaryBalances[_batchId][msg.sender] >= _transferAmount, "Insufficient balance for transfer.");
        
        // Verify ZKP proof to confirm the transfer details without revealing them
        require(zkpVerifier.verifyProof(_zkpProof, _publicInputs), "Invalid ZKP proof");

        
        beneficiaryBalances[_batchId][msg.sender] -= _transferAmount;
        beneficiaryBalances[_batchId][_newOwner] += _transferAmount;

        emit OwnershipTransferred(_batchId, msg.sender, _newOwner, _transferAmount);
    }

    function withdrawPrivately(
        uint256 _batchId,
        uint256 _withdrawAmount,
        string calldata _metadata
    ) external validBatchId(_batchId) {

        // The function will allow the user to withdraw without attestation. The following code is under development

        Batch storage batch = batchRegistry[_batchId];
        require(!batch.isFinalized, "Batch has already been finalized.");
        require(beneficiaryBalances[_batchId][msg.sender] >= _withdrawAmount, "Insufficient balance for withdrawal.");

        beneficiaryBalances[_batchId][msg.sender] -= _withdrawAmount;
        batch.remainingSupply -= _withdrawAmount;

        token.safeTransfer(msg.sender, _withdrawAmount);

        if (batch.remainingSupply == 0) {
            finalizeBatch(_batchId);
        }
    }

    function withdrawWithAttestationProof(uint256 _batchId, uint256 _withdrawAmount, string calldata _metadata) external validBatchId(_batchId) {
        
        Batch storage batch = batchRegistry[_batchId];
        require(!batch.isFinalized, "Batch has already been finalized.");
        require(beneficiaryBalances[_batchId][msg.sender] >= _withdrawAmount, "Insufficient balance for withdrawal.");

        beneficiaryBalances[_batchId][msg.sender] -= _withdrawAmount;
        batch.remainingSupply -= _withdrawAmount;

        token.safeTransfer(msg.sender, _withdrawAmount);
        batch.token.transfer(msg.sender, _withdrawAmount);

        emit AttestedWithdrawal(_batchId, msg.sender, _withdrawAmount, batch.attestationDetails, _metadata);

        if (batch.remainingSupply == 0) {
            finalizeBatch(_batchId);
        }
    }

    function finalizeBatch(uint256 _batchId) internal {
        Batch storage batch = batchRegistry[_batchId];
        require(!batch.isFinalized, "Batch is already finalized.");
        require(batch.remainingSupply == 0, "There are still unwithdrawn tokens.");

        batch.isFinalized = true;
        emit BatchFinalized(_batchId);
    }

    function modifyBatchAttestation(uint256 _batchId, string calldata _newAttestationDetails) external validBatchId(_batchId) onlyBatchOwner(_batchId) {
        Batch storage batch = batchRegistry[_batchId];
        require(!batch.isFinalized, "Cannot update attestation for a finalized batch.");

        batch.attestationDetails = _newAttestationDetails;
        emit BatchUpdated(_batchId, _newAttestationDetails);
    }
}
