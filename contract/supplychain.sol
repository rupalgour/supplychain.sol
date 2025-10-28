// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title SciValidate
 * @dev Decentralized Scientific Research Validation Platform
 * @notice This contract manages research paper submissions, peer reviews, and researcher reputation
 */
contract SciValidate {
    
    // Structs
    struct ResearchPaper {
        string paperHash; // IPFS hash of the research paper
        address author;
        uint256 timestamp;
        uint256 reviewCount;
        uint256 approvalCount;
        uint256 rejectionCount;
        bool isPublished;
        string[] revisionHashes; // Track all versions
    }
    
    struct Review {
        address reviewer;
        uint256 paperId;
        bool approved;
        string reviewHash; // IPFS hash of detailed review
        uint256 timestamp;
    }
    
    struct Researcher {
        address researcherAddress;
        uint256 reputationScore;
        uint256 papersSubmitted;
        uint256 reviewsCompleted;
        bool isVerified;
    }
    
    // State variables
    mapping(uint256 => ResearchPaper) public papers;
    mapping(address => Researcher) public researchers;
    mapping(uint256 => mapping(address => bool)) public hasReviewed;
    mapping(uint256 => Review[]) public paperReviews;
    
    uint256 public paperCount;
    uint256 public constant MIN_REVIEWS_FOR_PUBLICATION = 3;
    uint256 public constant REPUTATION_PER_REVIEW = 10;
    uint256 public constant REPUTATION_FOR_APPROVED_PAPER = 50;
    
    // Events
    event PaperSubmitted(uint256 indexed paperId, address indexed author, string paperHash);
    event PaperReviewed(uint256 indexed paperId, address indexed reviewer, bool approved);
    event PaperPublished(uint256 indexed paperId);
    event PaperRevised(uint256 indexed paperId, string newHash);
    event ResearcherVerified(address indexed researcher);
    
    // Modifiers
    modifier onlyVerifiedResearcher() {
        require(researchers[msg.sender].isVerified, "Researcher not verified");
        _;
    }
    
    modifier paperExists(uint256 _paperId) {
        require(_paperId < paperCount, "Paper does not exist");
        _;
    }
    
    /**
     * @dev Submit a new research paper
     * @param _paperHash IPFS hash of the research paper
     */
    function submitPaper(string memory _paperHash) external returns (uint256) {
        // Initialize researcher if new
        if (researchers[msg.sender].researcherAddress == address(0)) {
            researchers[msg.sender] = Researcher({
                researcherAddress: msg.sender,
                reputationScore: 0,
                papersSubmitted: 0,
                reviewsCompleted: 0,
                isVerified: true // Auto-verify for demo; in production, use verification process
            });
        }
        
        uint256 paperId = paperCount;
        papers[paperId] = ResearchPaper({
            paperHash: _paperHash,
            author: msg.sender,
            timestamp: block.timestamp,
            reviewCount: 0,
            approvalCount: 0,
            rejectionCount: 0,
            isPublished: false,
            revisionHashes: new string[](0)
        });
        
        papers[paperId].revisionHashes.push(_paperHash);
        researchers[msg.sender].papersSubmitted++;
        paperCount++;
        
        emit PaperSubmitted(paperId, msg.sender, _paperHash);
        return paperId;
    }
    
    /**
     * @dev Submit a peer review for a research paper
     * @param _paperId ID of the paper being reviewed
     * @param _approved Whether the reviewer approves the paper
     * @param _reviewHash IPFS hash of the detailed review comments
     */
    function submitReview(
        uint256 _paperId,
        bool _approved,
        string memory _reviewHash
    ) external onlyVerifiedResearcher paperExists(_paperId) {
        require(papers[_paperId].author != msg.sender, "Cannot review own paper");
        require(!hasReviewed[_paperId][msg.sender], "Already reviewed this paper");
        require(!papers[_paperId].isPublished, "Paper already published");
        
        // Create review
        Review memory newReview = Review({
            reviewer: msg.sender,
            paperId: _paperId,
            approved: _approved,
            reviewHash: _reviewHash,
            timestamp: block.timestamp
        });
        
        paperReviews[_paperId].push(newReview);
        hasReviewed[_paperId][msg.sender] = true;
        
        // Update paper stats
        papers[_paperId].reviewCount++;
        if (_approved) {
            papers[_paperId].approvalCount++;
        } else {
            papers[_paperId].rejectionCount++;
        }
        
        // Reward reviewer with reputation
        researchers[msg.sender].reputationScore += REPUTATION_PER_REVIEW;
        researchers[msg.sender].reviewsCompleted++;
        
        emit PaperReviewed(_paperId, msg.sender, _approved);
        
        // Auto-publish if meets criteria
        if (papers[_paperId].reviewCount >= MIN_REVIEWS_FOR_PUBLICATION) {
            uint256 approvalRate = (papers[_paperId].approvalCount * 100) / papers[_paperId].reviewCount;
            if (approvalRate >= 67) { // 2/3 majority
                _publishPaper(_paperId);
            }
        }
    }
    
    /**
     * @dev Publish a paper that has met review criteria
     * @param _paperId ID of the paper to publish
     */
    function _publishPaper(uint256 _paperId) internal {
        papers[_paperId].isPublished = true;
        
        // Reward author with reputation
        address author = papers[_paperId].author;
        researchers[author].reputationScore += REPUTATION_FOR_APPROVED_PAPER;
        
        emit PaperPublished(_paperId);
    }
    
    /**
     * @dev Submit a revision of an existing paper
     * @param _paperId ID of the paper being revised
     * @param _newPaperHash IPFS hash of the revised paper
     */
    function submitRevision(uint256 _paperId, string memory _newPaperHash) 
        external 
        paperExists(_paperId) 
    {
        require(papers[_paperId].author == msg.sender, "Only author can submit revisions");
        require(!papers[_paperId].isPublished, "Cannot revise published paper");
        
        papers[_paperId].paperHash = _newPaperHash;
        papers[_paperId].revisionHashes.push(_newPaperHash);
        
        emit PaperRevised(_paperId, _newPaperHash);
    }
    
    // View functions
    function getPaperDetails(uint256 _paperId) 
        external 
        view 
        paperExists(_paperId) 
        returns (
            string memory paperHash,
            address author,
            uint256 timestamp,
            uint256 reviewCount,
            uint256 approvalCount,
            uint256 rejectionCount,
            bool isPublished
        ) 
    {
        ResearchPaper memory paper = papers[_paperId];
        return (
            paper.paperHash,
            paper.author,
            paper.timestamp,
            paper.reviewCount,
            paper.approvalCount,
            paper.rejectionCount,
            paper.isPublished
        );
    }
    
    function getResearcherReputation(address _researcher) external view returns (uint256) {
        return researchers[_researcher].reputationScore;
    }
    
    function getPaperReviews(uint256 _paperId) 
        external 
        view 
        paperExists(_paperId) 
        returns (Review[] memory) 
    {
        return paperReviews[_paperId];
    }
    
    function getRevisionHistory(uint256 _paperId) 
        external 
        view 
        paperExists(_paperId) 
        returns (string[] memory) 
    {
        return papers[_paperId].revisionHashes;
    }
}
