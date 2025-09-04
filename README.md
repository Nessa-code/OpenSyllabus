# OpenSyllabus

A community-curated platform for course syllabi with voting, remixing, and creator credit tracking built on the Stacks blockchain.

## Features

- **Syllabus Publishing**: Educators can publish course syllabi with content hashes
- **Community Voting**: Students and educators vote on syllabus quality and usefulness
- **Remix Functionality**: Create new syllabi based on existing ones with proper attribution
- **Creator Credits**: Track contributions and build reputation through upvotes and creations

## Contract Functions

### Public Functions
- `publish-syllabus(title, subject, content-hash)` - Publish a new course syllabus
- `vote-syllabus(syllabus-id, upvote)` - Vote on a syllabus (true for upvote, false for downvote)
- `remix-syllabus(original-id, title, content-hash)` - Create a remix of an existing syllabus

### Read-Only Functions
- `get-syllabus(syllabus-id)` - Get syllabus details including votes and remix count
- `get-creator-credits(creator)` - Get creator's statistics and reputation
- `has-voted(syllabus-id, voter)` - Check if a user has already voted on a syllabus

## Usage

1. Deploy the contract to Stacks blockchain
2. Educators publish syllabi using `publish-syllabus`
3. Community votes on quality using `vote-syllabus`
4. Popular syllabi can be remixed using `remix-syllabus`
5. Track creator reputation through the credit system

## Data Structure

Each syllabus includes:
- Creator address and attribution
- Title and subject classification
- Content hash for off-chain storage
- Vote counts (upvotes/downvotes)
- Remix tracking and lineage
- Creation timestamp

## Credit System

Creators earn credits through:
- Publishing new syllabi
- Receiving upvotes from the community
- Having their work remixed by others

This creates incentives for high-quality educational content creation and curation.