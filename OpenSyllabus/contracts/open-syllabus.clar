;; OpenSyllabus - Community-curated course syllabi
(define-constant contract-owner tx-sender)
(define-constant err-not-found (err u101))
(define-constant err-already-voted (err u102))
(define-constant err-unauthorized (err u103))
(define-constant err-invalid-input (err u104))
(define-constant err-already-favorited (err u105))
(define-constant err-cannot-self-follow (err u106))
(define-constant err-already-following (err u107))
(define-constant err-insufficient-reputation (err u108))

(define-data-var next-syllabus-id uint u0)
(define-data-var next-category-id uint u0)
(define-data-var platform-fee uint u5) ;; 5% platform fee
(define-data-var min-reputation-to-create uint u10)

(define-map syllabi
  { syllabus-id: uint }
  {
    creator: principal,
    title: (string-ascii 100),
    subject: (string-ascii 50),
    content-hash: (string-ascii 64),
    description: (string-ascii 500),
    difficulty-level: uint, ;; 1-5 scale
    estimated-hours: uint,
    upvotes: uint,
    downvotes: uint,
    remix-count: uint,
    view-count: uint,
    favorite-count: uint,
    created-at: uint,
    updated-at: uint,
    is-premium: bool,
    price: uint,
    category-id: uint,
    tags: (list 5 (string-ascii 20))
  }
)

(define-map syllabus-votes
  { syllabus-id: uint, voter: principal }
  { vote-type: bool, voted-at: uint }
)

(define-map syllabus-favorites
  { syllabus-id: uint, user: principal }
  { favorited-at: uint }
)

(define-map remixes
  { original-id: uint, remix-id: uint }
  { remixer: principal, created-at: uint }
)

(define-map creator-credits
  { creator: principal }
  { 
    syllabi-created: uint, 
    total-upvotes: uint,
    total-downvotes: uint,
    reputation: uint,
    followers: uint,
    total-earnings: uint
  }
)

(define-map categories
  { category-id: uint }
  {
    name: (string-ascii 50),
    description: (string-ascii 200),
    syllabus-count: uint,
    created-by: principal,
    created-at: uint
  }
)

(define-map user-follows
  { follower: principal, following: principal }
  { followed-at: uint }
)

(define-map syllabus-reviews
  { syllabus-id: uint, reviewer: principal }
  {
    rating: uint, ;; 1-5 stars
    comment: (string-ascii 500),
    reviewed-at: uint
  }
)

(define-map syllabus-purchases
  { syllabus-id: uint, buyer: principal }
  { purchased-at: uint, price-paid: uint }
)

(define-map user-achievements
  { user: principal }
  {
    first-syllabus: bool,
    popular-creator: bool, ;; 100+ total upvotes
    prolific-creator: bool, ;; 10+ syllabi
    community-favorite: bool, ;; 50+ followers
    remix-master: bool ;; 5+ remixes created
  }
)