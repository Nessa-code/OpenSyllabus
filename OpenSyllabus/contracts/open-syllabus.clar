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

(define-public (purchase-syllabus (syllabus-id uint))
  (let ((buyer tx-sender)
        (syllabus (unwrap! (map-get? syllabi { syllabus-id: syllabus-id }) err-not-found)))
    (asserts! (get is-premium syllabus) err-invalid-input)
    (asserts! (is-none (map-get? syllabus-purchases { syllabus-id: syllabus-id, buyer: buyer })) err-already-voted)
    
    (let ((price (get price syllabus))
          (creator (get creator syllabus))
          (platform-cut (/ (* price (var-get platform-fee)) u100))
          (creator-earnings (- price platform-cut)))
      
      (try! (stx-transfer? price buyer contract-owner))
      (try! (stx-transfer? creator-earnings contract-owner creator))
      
      (map-set syllabus-purchases
        { syllabus-id: syllabus-id, buyer: buyer }
        { purchased-at: block-height, price-paid: price }
      )
      
      (update-creator-earnings creator creator-earnings)
      (ok true)
    )
  )
)

(define-public (create-category (name (string-ascii 50)) (description (string-ascii 200)))
  (let ((category-id (var-get next-category-id)))
    (asserts! (> (len name) u0) err-invalid-input)
    
    (map-set categories
      { category-id: category-id }
      {
        name: name,
        description: description,
        syllabus-count: u0,
        created-by: tx-sender,
        created-at: block-height
      }
    )
    (var-set next-category-id (+ category-id u1))
    (ok category-id)
  )
)

(define-public (remix-syllabus (original-id uint) (title (string-ascii 100)) (content-hash (string-ascii 64)))
  (let (
    (original (unwrap! (map-get? syllabi { syllabus-id: original-id }) err-not-found))
    (new-id (var-get next-syllabus-id))
  )
    (try! (publish-syllabus 
           title 
           (get subject original) 
           content-hash
           (get description original)
           (get difficulty-level original)
           (get estimated-hours original)
           false ;; remixes are free
           u0
           (get category-id original)
           (get tags original)))
    
    (map-set remixes
      { original-id: original-id, remix-id: new-id }
      { remixer: tx-sender, created-at: block-height }
    )
    (map-set syllabi
      { syllabus-id: original-id }
      (merge original { remix-count: (+ (get remix-count original) u1) })
    )
    (check-and-award-achievements tx-sender)
    (ok new-id)
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

;; Private helper functions
(define-private (update-creator-credits (creator principal))
  (let ((current-credits (default-to 
                         { syllabi-created: u0, total-upvotes: u0, total-downvotes: u0, 
                           reputation: u0, followers: u0, total-earnings: u0 } 
                         (map-get? creator-credits { creator: creator }))))
    (map-set creator-credits
      { creator: creator }
      (merge current-credits { syllabi-created: (+ (get syllabi-created current-credits) u1) })
    )
  )
)

(define-private (update-creator-reputation (creator principal) (positive bool))
  (let ((current-credits (default-to 
                         { syllabi-created: u0, total-upvotes: u0, total-downvotes: u0, 
                           reputation: u0, followers: u0, total-earnings: u0 } 
                         (map-get? creator-credits { creator: creator }))))
    (if positive
      (map-set creator-credits
        { creator: creator }
        (merge current-credits 
               { total-upvotes: (+ (get total-upvotes current-credits) u1),
                 reputation: (+ (get reputation current-credits) u2) })
      )
      (map-set creator-credits
        { creator: creator }
        (merge current-credits 
               { total-downvotes: (+ (get total-downvotes current-credits) u1),
                 reputation: (if (> (get reputation current-credits) u0) 
                           (- (get reputation current-credits) u1) 
                           u0) })
      )
    )
  )
)

(define-private (update-creator-earnings (creator principal) (amount uint))
  (let ((current-credits (default-to 
                         { syllabi-created: u0, total-upvotes: u0, total-downvotes: u0, 
                           reputation: u0, followers: u0, total-earnings: u0 } 
                         (map-get? creator-credits { creator: creator }))))
    (map-set creator-credits
      { creator: creator }
      (merge current-credits { total-earnings: (+ (get total-earnings current-credits) amount) })
    )
  )
)

(define-private (increment-category-count (category-id uint))
  (let ((category (map-get? categories { category-id: category-id })))
    (match category
      some-category (map-set categories
                     { category-id: category-id }
                     (merge some-category { syllabus-count: (+ (get syllabus-count some-category) u1) }))
      false
    )
  )
)

(define-private (check-and-award-achievements (user principal))
  (let ((credits (default-to 
                 { syllabi-created: u0, total-upvotes: u0, total-downvotes: u0, 
                   reputation: u0, followers: u0, total-earnings: u0 } 
                 (map-get? creator-credits { creator: user })))
        (current-achievements (default-to 
                              { first-syllabus: false, popular-creator: false, 
                                prolific-creator: false, community-favorite: false, remix-master: false }
                              (map-get? user-achievements { user: user }))))
    
    (map-set user-achievements
      { user: user }
      {
        first-syllabus: (or (get first-syllabus current-achievements) (>= (get syllabi-created credits) u1)),
        popular-creator: (or (get popular-creator current-achievements) (>= (get total-upvotes credits) u100)),
        prolific-creator: (or (get prolific-creator current-achievements) (>= (get syllabi-created credits) u10)),
        community-favorite: (or (get community-favorite current-achievements) (>= (get followers credits) u50)),
        remix-master: (or (get remix-master current-achievements) (>= (count-user-remixes user) u5))
      }
    )
  )
)

(define-private (count-user-remixes (user principal))
  ;; This is a simplified count - in practice you'd need a more complex implementation
  u0
)

;; Read-only functions
(define-read-only (get-syllabus (syllabus-id uint))
  (map-get? syllabi { syllabus-id: syllabus-id })
)

(define-read-only (get-creator-credits (creator principal))
  (map-get? creator-credits { creator: creator })
)

(define-read-only (has-voted (syllabus-id uint) (voter principal))
  (is-some (map-get? syllabus-votes { syllabus-id: syllabus-id, voter: voter }))
)

(define-read-only (get-user-reputation (user principal))
  (get reputation 
       (default-to 
        { syllabi-created: u0, total-upvotes: u0, total-downvotes: u0, 
          reputation: u0, followers: u0, total-earnings: u0 } 
        (map-get? creator-credits { creator: user })))
)

(define-read-only (get-category (category-id uint))
  (map-get? categories { category-id: category-id })
)

(define-read-only (is-following (follower principal) (following principal))
  (is-some (map-get? user-follows { follower: follower, following: following }))
)

(define-read-only (get-user-achievements (user principal))
  (map-get? user-achievements { user: user })
)

(define-read-only (has-purchased (syllabus-id uint) (user principal))
  (is-some (map-get? syllabus-purchases { syllabus-id: syllabus-id, buyer: user }))
)