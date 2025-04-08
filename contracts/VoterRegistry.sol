pragma solidity ^0.8.0;

/**
 * @dev Manages voter registration and verification
 */
contract VoterRegistry {
    struct Voter {
        bytes32 voterIdHash;    // Hashed ID of the voter
        bool isRegistered;      // Whether the voter is registered
        bool hasVoted;          // Whether the voter has already voted
        address voterAddress;   // Blockchain address of the voter
    }
    
    mapping(bytes32 => Voter) public voters;
    address public admin;
    
    event VoterRegistered(bytes32 indexed voterIdHash);
    event VoterMarkedAsVoted(bytes32 indexed voterIdHash);
    
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }
    
    constructor() {
        admin = msg.sender;
    }
    
    /**
     * @dev Register a new voter
     * @param _voterIdHash Hashed ID of the voter
     * @param _voterAddress Blockchain address of the voter
     */
    function registerVoter(bytes32 _voterIdHash, address _voterAddress) public onlyAdmin {
        require(!voters[_voterIdHash].isRegistered, "Voter already registered");
        
        voters[_voterIdHash] = Voter({
            voterIdHash: _voterIdHash,
            isRegistered: true,
            hasVoted: false,
            voterAddress: _voterAddress
        });
        
        emit VoterRegistered(_voterIdHash);
    }
    
    /**
     * @dev Check if a voter is eligible to vote
     * @param _voterIdHash Hashed ID of the voter
     * @return Whether the voter is eligible
     */
    function isVoterEligible(bytes32 _voterIdHash) public view returns (bool) {
        return voters[_voterIdHash].isRegistered && !voters[_voterIdHash].hasVoted;
    }
    
    /**
     * @dev Mark a voter as having voted
     * @param _voterIdHash Hashed ID of the voter
     */
    function markVoted(bytes32 _voterIdHash) public onlyAdmin {
        require(voters[_voterIdHash].isRegistered, "Voter not registered");
        require(!voters[_voterIdHash].hasVoted, "Voter has already voted");
        
        voters[_voterIdHash].hasVoted = true;
        
        emit VoterMarkedAsVoted(_voterIdHash);
    }
}

/**
 * @title Election
 * @dev Manages election details and voting process
 */
contract Election {
    struct Candidate {
        uint256 id;             // Candidate ID
        string name;            // Candidate name
        string party;           // Political party
        uint256 voteCount;      // Number of votes received
    }
    
    struct ElectionDetails {
        string name;            // Name of the election
        uint256 startTime;      // Start timestamp
        uint256 endTime;        // End timestamp
        bool isActive;          // Whether the election is currently active
        bool resultDeclared;    // Whether results have been declared
    }
    
    ElectionDetails public electionDetails;
    Candidate[] public candidates;
    VoterRegistry public voterRegistry;
    
    // Maps voter ID hash to candidate ID they voted for
    mapping(bytes32 => uint256) private votes;
    
    event VoteCast(bytes32 indexed voterIdHash, uint256 candidateId);
    event ElectionStarted(string name, uint256 startTime, uint256 endTime);
    event ElectionEnded(uint256 endTime);
    event ResultDeclared();
    
    modifier onlyDuringElection() {
        require(electionDetails.isActive, "Election is not active");
        require(block.timestamp >= electionDetails.startTime, "Election has not started yet");
        require(block.timestamp <= electionDetails.endTime, "Election has ended");
        _;
    }
    
    modifier onlyAdmin() {
        require(msg.sender == voterRegistry.admin(), "Only admin can perform this action");
        _;
    }
    
    /**
     * @dev Constructor to set up the election
     * @param _name Name of the election
     * @param _voterRegistryAddress Address of the voter registry contract
     */
    constructor(string memory _name, address _voterRegistryAddress) {
        voterRegistry = VoterRegistry(_voterRegistryAddress);
        electionDetails.name = _name;
        electionDetails.isActive = false;
        electionDetails.resultDeclared = false;
    }
    
    /**
     * @dev Add a candidate to the election
     * @param _name Name of the candidate
     * @param _party Political party of the candidate
     */
    function addCandidate(string memory _name, string memory _party) public onlyAdmin {
        require(!electionDetails.isActive, "Cannot add candidates during active election");
        
        uint256 candidateId = candidates.length;
        candidates.push(Candidate({
            id: candidateId,
            name: _name,
            party: _party,
            voteCount: 0
        }));
    }
    
    /**
     * @dev Start the election
     * @param _startTime Start timestamp of the election
     * @param _endTime End timestamp of the election
     */
    function startElection(uint256 _startTime, uint256 _endTime) public onlyAdmin {
        require(!electionDetails.isActive, "Election is already active");
        require(_endTime > _startTime, "End time must be after start time");
        require(candidates.length > 0, "No candidates added");
        
        electionDetails.startTime = _startTime;
        electionDetails.endTime = _endTime;
        electionDetails.isActive = true;
        
        emit ElectionStarted(electionDetails.name, _startTime, _endTime);
    }
    
    /**
     * @dev Cast a vote
     * @param _voterIdHash Hashed ID of the voter
     * @param _candidateId ID of the candidate to vote for
     */
    function castVote(bytes32 _voterIdHash, uint256 _candidateId) public onlyDuringElection {
        require(voterRegistry.isVoterEligible(_voterIdHash), "Voter is not eligible");
        require(_candidateId < candidates.length, "Invalid candidate ID");
        
        // Mark the voter as having voted
        voterRegistry.markVoted(_voterIdHash);
        
        // Record the vote
        votes[_voterIdHash] = _candidateId;
        candidates[_candidateId].voteCount++;
        
        emit VoteCast(_voterIdHash, _candidateId);
    }
    
    /**
     * @dev End the election
     */
    function endElection() public onlyAdmin {
        require(electionDetails.isActive, "Election is not active");
        require(block.timestamp >= electionDetails.endTime, "Election end time not reached");
        
        electionDetails.isActive = false;
        
        emit ElectionEnded(block.timestamp);
    }
    
    /**
     * @dev Declare the election results
     */
    function declareResults() public onlyAdmin {
        require(!electionDetails.isActive, "Cannot declare results during active election");
        require(!electionDetails.resultDeclared, "Results already declared");
        
        electionDetails.resultDeclared = true;
        
        emit ResultDeclared();
    }
    
    /**
     * @dev Get the number of candidates
     * @return Number of candidates
     */
    function getCandidateCount() public view returns (uint256) {
        return candidates.length;
    }
    
    /**
     * @dev Get election results
     * @return Array of candidate IDs and their vote counts
     */
    function getResults() public view returns (uint256[] memory, uint256[] memory) {
        require(electionDetails.resultDeclared, "Results not declared yet");
        
        uint256[] memory candidateIds = new uint256[](candidates.length);
        uint256[] memory voteCounts = new uint256[](candidates.length);
        
        for (uint256 i = 0; i < candidates.length; i++) {
            candidateIds[i] = candidates[i].id;
            voteCounts[i] = candidates[i].voteCount;
        }
        
        return (candidateIds, voteCounts);
    }
}
