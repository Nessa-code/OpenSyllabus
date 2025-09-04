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

(define-public (publish-syllabus 
    (title (string-ascii 100)) 
    (subject (string-ascii 50)) 
    (content-hash (string-ascii 64))
    (description (string-ascii 500))
    (difficulty-level uint)
    (estimated-hours uint)
    (is-premium bool)
    (price uint)
    (category-id uint)
    (tags (list 5 (string-ascii 20))))
  (let ((syllabus-id (var-get next-syllabus-id))
        (creator-rep (get-user-reputation tx-sender)))
    (asserts! (>= creator-rep (var-get min-reputation-to-create)) err-insufficient-reputation)
    (asserts! (<= difficulty-level u5) err-invalid-input)
    (asserts! (> (len title) u0) err-invalid-input)
    
    (map-set syllabi
      { syllabus-id: syllabus-id }
      {
        creator: tx-sender,
        title: title,
        subject: subject,
        content-hash: content-hash,
        description: description,
        difficulty-level: difficulty-level,
        estimated-hours: estimated-hours,
        upvotes: u0,
        downvotes: u0,
        remix-count: u0,
        view-count: u0,
        favorite-count: u0,
        created-at: block-height,
        updated-at: block-height,
        is-premium: is-premium,
        price: price,
        category-id: category-id,
        tags: tags
      }
    )
    (var-set next-syllabus-id (+ syllabus-id u1))
    (update-creator-credits tx-sender)
    (increment-category-count category-id)
    (check-and-award-achievements tx-sender)
    (ok syllabus-id)
  )
)

(define-public (vote-syllabus (syllabus-id uint) (upvote bool))
  (let ((voter tx-sender))
    (asserts! (is-none (map-get? syllabus-votes { syllabus-id: syllabus-id, voter: voter })) err-already-voted)
    (asserts! (is-some (map-get? syllabi { syllabus-id: syllabus-id })) err-not-found)
    
    (map-set syllabus-votes 
      { syllabus-id: syllabus-id, voter: voter } 
      { vote-type: upvote, voted-at: block-height })
    
    (let ((syllabus (unwrap-panic (map-get? syllabi { syllabus-id: syllabus-id }))))
      (if upvote
        (begin
          (map-set syllabi
            { syllabus-id: syllabus-id }
            (merge syllabus { upvotes: (+ (get upvotes syllabus) u1) })
          )
          (update-creator-reputation (get creator syllabus) true)
        )
        (begin
          (map-set syllabi
            { syllabus-id: syllabus-id }
            (merge syllabus { downvotes: (+ (get downvotes syllabus) u1) })
          )
          (update-creator-reputation (get creator syllabus) false)
        )
      )
    )
    (ok true)
  )
)

(define-public (increment-view-count (syllabus-id uint))
  (let ((syllabus (unwrap! (map-get? syllabi { syllabus-id: syllabus-id }) err-not-found)))
    (map-set syllabi
      { syllabus-id: syllabus-id }
      (merge syllabus { view-count: (+ (get view-count syllabus) u1) })
    )
    (ok true)
  )
)

(define-public (favorite-syllabus (syllabus-id uint))
  (let ((user tx-sender))
    (asserts! (is-none (map-get? syllabus-favorites { syllabus-id: syllabus-id, user: user })) err-already-favorited)
    (asserts! (is-some (map-get? syllabi { syllabus-id: syllabus-id })) err-not-found)
    
    (map-set syllabus-favorites 
      { syllabus-id: syllabus-id, user: user } 
      { favorited-at: block-height })
    
    (let ((syllabus (unwrap-panic (map-get? syllabi { syllabus-id: syllabus-id }))))
      (map-set syllabi
        { syllabus-id: syllabus-id }
        (merge syllabus { favorite-count: (+ (get favorite-count syllabus) u1) })
      )
    )
    (ok true)
  )
)

(define-public (follow-user (user-to-follow principal))
  (let ((follower tx-sender))
    (asserts! (not (is-eq follower user-to-follow)) err-cannot-self-follow)
    (asserts! (is-none (map-get? user-follows { follower: follower, following: user-to-follow })) err-already-following)
    
    (map-set user-follows 
      { follower: follower, following: user-to-follow } 
      { followed-at: block-height })
    
    (let ((current-credits (default-to 
                           { syllabi-created: u0, total-upvotes: u0, total-downvotes: u0, 
                             reputation: u0, followers: u0, total-earnings: u0 } 
                           (map-get? creator-credits { creator: user-to-follow }))))
      (map-set creator-credits
        { creator: user-to-follow }
        (merge current-credits { followers: (+ (get followers current-credits) u1) })
      )
    )
    (check-and-award-achievements user-to-follow)
    (ok true)
  )
)

(define-public (add-review (syllabus-id uint) (rating uint) (comment (string-ascii 500)))
  (let ((reviewer tx-sender))
    (asserts! (is-some (map-get? syllabi { syllabus-id: syllabus-id })) err-not-found)
    (asserts! (and (>= rating u1) (<= rating u5)) err-invalid-input)
    
    (map-set syllabus-reviews
      { syllabus-id: syllabus-id, reviewer: reviewer }
      { rating: rating, comment: comment, reviewed-at: block-height }
    )
    (ok true)
  )
)