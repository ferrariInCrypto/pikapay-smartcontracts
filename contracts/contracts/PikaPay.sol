// SPDX-License-Identifier: MIT

pragma solidity ^0.8.27;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./PikaFractionalAttestationToken.sol";
import "./ZKPVerifier.sol"; // Import zk-SNARK verifier

//@@ This contract is under development

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

    mapping(uint256 => bytes32) public commitments; // Store commitments for each batch
    mapping(uint256 => Batch) public batchRegistry;
    mapping(uint256 => mapping(address => uint256)) private beneficiaryBalances;
    mapping(bytes32 => bool) private spentNullifiers; // Prevent double-spending by tracking nullifiers

    event BatchCreated(
        uint256 batchId,
        address indexed owner,
        string attestationDetails,
        uint256 totalAmount
    );
    event AttestedWithdrawal(
        uint256 batchId,
        address indexed beneficiary,
        uint256 amount,
        string attestation,
        string metadata
    );
    event BatchFinalized(uint256 batchId);
    event BatchUpdated(uint256 batchId, string updatedAttestationDetails);
    event OwnershipTransferred(
        uint256 batchId,
        address indexed previousOwner,
        address indexed newOwner,
        uint256 amount
    );

    ERC20 public token; // USDT Token address
    ZKPVerifier public zkpVerifier; // zk-SNARK verifier contract

    // Constructor accepts the ERC20 token address and the ZKP verifier address
    constructor(address _tokenAddress, address _zkpVerifierAddress) {
        token = ERC20(_tokenAddress);
        zkpVerifier = ZKPVerifier(_zkpVerifierAddress); // Initialize the verifier contract
    }

    modifier onlyBatchOwner(uint256 _batchId) {
        require(
            batchRegistry[_batchId].owner == msg.sender,
            "Caller is not the batch owner"
        );
        _;
    }

    modifier validBatchId(uint256 _batchId) {
        require(_batchId > 0 && _batchId <= totalBatches, "Invalid batch ID");
        _;
    }

    function createNewBatchWithAttestation(
        string calldata _attestationDetails,
        uint256 _depositAmount
    ) external {
        require(_depositAmount > 0, "Deposit amount must be greater than 0");

        totalBatches += 1;
        token.safeTransferFrom(msg.sender, address(this), _depositAmount);

        PikaFractionalAttestationToken fractionalToken = new PikaFractionalAttestationToken(
                this,
                totalBatches,
                _depositAmount
            );

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
        emit BatchCreated(
            totalBatches,
            msg.sender,
            _attestationDetails,
            _depositAmount
        );
    }

    function _transferBatchOwnership(
        uint256 _batchId,
        address _newOwner,
        bytes calldata proof, // ZKP proof verifying balance ownership
        bytes32 newCommitment, // New commitment after transfer
        bytes32 nullifier // Nullifier to mark old balance as spent
    ) internal onlyBatchOwner(_batchId) validBatchId(_batchId) {
        require(_newOwner != address(0), "Invalid new owner address");
        require(!spentNullifiers[nullifier], "Balance already spent");

        // Verifing the ZK proof using the on-chain verifier

        bool isValid = zkpVerifier.verifyProof(
            proof,
            [newCommitment, nullifier]
        );
        require(isValid, "Invalid ZK proof");

        // Update state
        spentNullifiers[nullifier] = true; // Mark the old balance as spent
        commitments[_batchId] = newCommitment; // Store the new commitment

        emit OwnershipTransferred(
            _batchId,
            msg.sender,
            _newOwner,
            beneficiaryBalances[_batchId][msg.sender]
        );
    }


     function withdrawPrivatelyWithoutAttestation(
        uint256 _batchId,
        uint256 _withdrawAmount,
        bytes calldata proof,
        bytes32 newCommitment,
        bytes32 nullifier,
        string calldata _metadata
    ) external validBatchId(_batchId) {
        Batch storage batch = batchRegistry[_batchId];
        require(!batch.isFinalized, "Batch has already been finalized.");
        require(!spentNullifiers[nullifier], "Balance already spent");

        // Verify ZKP proof for withdrawal
        bool isValid = zkpVerifier.verifyProof(
            proof,
            [newCommitment, nullifier]
        );
        require(isValid, "Invalid ZK proof");

        // require(
        //     beneficiaryBalances[_batchId][msg.sender] >= _withdrawAmount,
        //     "Insufficient balance for withdrawal."
        // );

        // beneficiaryBalances[_batchId][msg.sender] -= _withdrawAmount;
        // batch.remainingSupply -= _withdrawAmount;

        // Transfer tokens
        token.safeTransfer(msg.sender, _withdrawAmount);
        spentNullifiers[nullifier] = true;
        commitments[_batchId] = newCommitment;

        emit AttestedWithdrawal(
            _batchId,
            msg.sender,
            _withdrawAmount,
            batch.attestationDetails,
            _metadata
        );

        // Finalize the batch if supply is zero
        if (batch.remainingSupply == 0) {
            finalizeBatch(_batchId);
        }
    }


    function withdrawWithAttestationProof(
        uint256 _batchId,
        uint256 _withdrawAmount,
        string calldata _metadata
    ) external validBatchId(_batchId) {
        Batch storage batch = batchRegistry[_batchId];
        require(!batch.isFinalized, "Batch has already been finalized.");
        require(!spentNullifiers[nullifier], "Balance already spent");

        // Verify ZKP proof for withdrawal
        bool isValid = zkpVerifier.verifyProof(
            proof,
            [newCommitment, nullifier]
        );
        require(isValid, "Invalid ZK proof");

        batch.token.transfer(msg.sender, _withdrawAmount);

        token.safeTransfer(msg.sender, _withdrawAmount);
        spentNullifiers[nullifier] = true;
        commitments[_batchId] = newCommitment;

        emit AttestedWithdrawal(
            _batchId,
            msg.sender,
            _withdrawAmount,
            batch.attestationDetails,
            _metadata
        );

        // Finalize the batch if supply is zero
        if (batch.remainingSupply == 0) {
            finalizeBatch(_batchId);
        }

        emit AttestedWithdrawal(
            _batchId,
            msg.sender,
            _withdrawAmount,
            batch.attestationDetails,
            _metadata
        );

        if (batch.remainingSupply == 0) {
            finalizeBatch(_batchId);
        }
    }


  
    function finalizeBatch(uint256 _batchId) internal {
        Batch storage batch = batchRegistry[_batchId];
        require(!batch.isFinalized, "Batch is already finalized.");
        require(
            batch.remainingSupply == 0,
            "There are still unwithdrawn tokens."
        );

        batch.isFinalized = true;
        emit BatchFinalized(_batchId);
    }

    function modifyBatchAttestation(
        uint256 _batchId,
        string calldata _newAttestationDetails
    ) external validBatchId(_batchId) onlyBatchOwner(_batchId) {
        Batch storage batch = batchRegistry[_batchId];
        require(
            !batch.isFinalized,
            "Cannot update attestation for a finalized batch."
        );

        batch.attestationDetails = _newAttestationDetails;
        emit BatchUpdated(_batchId, _newAttestationDetails);
    }
}
