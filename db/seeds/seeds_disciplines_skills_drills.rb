# Snapshot seed for the current Discipline, Skill, Drill, and DrillSkill data.
# Run with: bin/rails runner db/seeds/seeds_disciplines_skills_drills.rb
require "json"

DISCIPLINE_NAMES = [
  "Attack",
  "Block",
  "Defence",
  "Serve",
  "Reception",
  "Strategy",
  "Tactics",
  "Set"
].freeze
SKILLS_DATA = [
  {
    "title": "Hand Setting",
    "discipline": "Set",
    "description": "Overhead setting technique",
    "slug": "hand-setting",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "Which side to choose",
    "discipline": "Strategy",
    "description": "Analyze opponent positioning and movement patterns to determine optimal serving targets. Consider their weaker side, footwork speed, and court coverage tendencies.",
    "slug": "which-side-to-choose",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "When start receiving or serving",
    "discipline": "Strategy",
    "description": "Understand the optimal timing to begin your approach movement based on the ball trajectory and your position on the court. Anticipate early to maximize preparation time.",
    "slug": "when-start-receiving-or-serving",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "Who to serve on. When serve middle.",
    "discipline": "Strategy",
    "description": "Identify which opponent to target with serves based on their reception skills. Serving to the middle can create confusion about who should take the ball.",
    "slug": "who-to-serve-on-when-serve-middle",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "When ask for time out",
    "discipline": "Strategy",
    "description": "Recognize situations that warrant a timeout: when losing momentum, when opponent has a scoring run, or when players need to reset mentally. Maximum 1 per set in beach volleyball.",
    "slug": "when-ask-for-time-out",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "How to use the wind and sun in your favor",
    "discipline": "Strategy",
    "description": "Adapt your strategy based on environmental conditions. Use wind direction for float serves, position yourself to avoid sun glare, and adjust shot selection accordingly.",
    "slug": "how-to-use-the-wind-and-sun-in-your-favor",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "When short/long",
    "discipline": "Strategy",
    "description": "Decide when to play short shots versus deep shots based on opponent positioning. Short shots exploit open court behind blockers, long shots push opponents back.",
    "slug": "when-short-long",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "When do seconds",
    "discipline": "Strategy",
    "description": "Know when to attack on the second ball instead of setting. This surprise tactic can catch opponents off guard when they expect a standard set-attack pattern.",
    "slug": "when-do-seconds",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "Always play close",
    "discipline": "Strategy",
    "description": "Maintain compact court positioning with your partner. Being close together reduces gaps in coverage and allows for better communication and transition play.",
    "slug": "always-play-close",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "Always talk. What to talk. Who talks",
    "discipline": "Strategy",
    "description": "Maintain constant verbal communication about ball coverage, opponent positioning, and play calls. The player behind the ball typically directs the play.",
    "slug": "always-talk-what-to-talk-who-talks",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "Priority on the right or left",
    "discipline": "Strategy",
    "description": "Determine which side of the court to prioritize based on your strengths and opponent weaknesses. Establish clear coverage responsibilities for each side.",
    "slug": "priority-on-the-right-or-left",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "Who is middle",
    "discipline": "Strategy",
    "description": "Clarify which player covers the middle of the court in different situations. Clear middle coverage assignments prevent balls from dropping between players.",
    "slug": "who-is-middle",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "Court position (always close to each other)",
    "discipline": "Strategy",
    "description": "Maintain optimal spacing between partners based on game situation. Closer for defense, slightly wider for coverage, always within communication range.",
    "slug": "court-position-always-close-to-each-other",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "Read other players' body",
    "discipline": "Strategy",
    "description": "Observe opponent body language, foot positioning, and arm movements to anticipate their next play. Early reading provides crucial reaction time advantages.",
    "slug": "read-other-players-body",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "Position to serve receive",
    "discipline": "Strategy",
    "description": "Establish optimal serve receive positioning based on server tendencies, wind conditions, and your team strengths. Balance court coverage with attacking preparation.",
    "slug": "position-to-serve-receive",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "Behind the ball",
    "discipline": "Defence",
    "description": "Position yourself directly behind the ball trajectory to create a stable platform for controlled defensive plays. This alignment maximizes your field of vision and reaction time.",
    "slug": "behind-the-ball",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "Lateral/shoulder",
    "discipline": "Defence",
    "description": "Execute lateral defensive movements using proper shoulder rotation and hip alignment. Move sideways efficiently while maintaining balance and readiness to react.",
    "slug": "lateral-shoulder",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "Lateral high",
    "discipline": "Defence",
    "description": "Defend high balls coming from the side using extended reach and proper body positioning. Use your arms at maximum height while maintaining body control.",
    "slug": "lateral-high",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "Lateral moving",
    "discipline": "Defence",
    "description": "Move laterally while maintaining defensive stance and court awareness. Shuffle steps and crossover techniques for efficient side-to-side coverage.",
    "slug": "lateral-moving",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "Behind normal",
    "discipline": "Defence",
    "description": "Position yourself in the standard defensive spot behind the expected hit trajectory. This default position optimizes your ability to react to various shot types.",
    "slug": "behind-normal",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "Behind with scoop",
    "discipline": "Defence",
    "description": "Use a scooping motion when defending balls that drop short or require reaching below waist level. Keep arms together and use legs for upward momentum.",
    "slug": "behind-with-scoop",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "Front short, both arms",
    "discipline": "Defence",
    "description": "Defend short balls at the net using both arms extended forward. Quick reaction and soft hands are essential for controlled digs on sharp angle shots.",
    "slug": "front-short-both-arms",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "Front short, one arm",
    "discipline": "Defence",
    "description": "Use single-arm digs for balls that require extended reach at the net. This technique covers more court area but requires precise timing and control.",
    "slug": "front-short-one-arm",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "Tomahawk",
    "discipline": "Defence",
    "description": "Execute the tomahawk defensive technique for hard-driven balls at close range. Use overhead arm motion to redirect balls upward when traditional digs are not possible.",
    "slug": "tomahawk",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "Poke",
    "discipline": "Defence",
    "description": "Use finger poke technique for soft defensive plays on short balls. Requires precise finger strength and touch to control ball direction and height.",
    "slug": "poke",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "Transition to attack",
    "discipline": "Defence",
    "description": "Quickly move from defensive positioning to attacking readiness after a successful dig. Anticipate the set and prepare for your hitting approach.",
    "slug": "transition-to-attack",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "Opposite from block",
    "discipline": "Defence",
    "description": "Position yourself opposite to where your partner is blocking. This creates optimal court coverage and reduces defensive gaps.",
    "slug": "opposite-from-block",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "Saving hard driven hit - dig",
    "discipline": "Defence",
    "description": "Use low, stable platform technique to absorb and redirect hard-driven attacks. Focus on cushioning the ball with arms while maintaining body control.",
    "slug": "saving-hard-driven-hit-dig",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "Saving hard driven hit - high",
    "discipline": "Defence",
    "description": "Defend hard-driven balls that travel at chest height or above. Use hands positioned up with soft touch to redirect balls to target.",
    "slug": "saving-hard-driven-hit-high",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "Gator",
    "discipline": "Defence",
    "description": "Use the gator technique for balls that require digging with hands together and rolling motion. Effective for hard-driven balls at close range.",
    "slug": "gator",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "Saving after ball on the net",
    "discipline": "Defence",
    "description": "Recover and play balls that hit the net and drop on your side. Quick reflexes and anticipation are key for these unpredictable bounces.",
    "slug": "saving-after-ball-on-the-net",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "Dig",
    "discipline": "Set",
    "description": "Execute a setting motion starting from a dig position. This technique combines defensive reception with setting accuracy in one fluid motion.",
    "slug": "dig",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "Handset",
    "discipline": "Set",
    "description": "Perform overhead setting using proper hand positioning with fingers spread and thumbs pointing toward face. Control ball trajectory through fingertip contact and extension.",
    "slug": "handset",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "Back set",
    "discipline": "Set",
    "description": "Direct the set behind the setter toward the right-side attacker. Requires proper body rotation, arm extension, and consistent release point for accuracy.",
    "slug": "back-set",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "From back of the court",
    "discipline": "Set",
    "description": "Execute sets from deep court positions. Requires stronger arm action and higher arc to give attackers time to approach and hit effectively.",
    "slug": "from-back-of-the-court",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "Knees on the sand",
    "discipline": "Set",
    "description": "Set from a kneeling position when necessary for low balls or emergency situations. Maintain hand position while generating power from arm extension.",
    "slug": "knees-on-the-sand",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "Foot work",
    "discipline": "Set",
    "description": "Use proper footwork to get behind the ball quickly and efficiently. Small adjustment steps and shuffle patterns optimize setting position and balance.",
    "slug": "foot-work",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "Set with wind",
    "discipline": "Set",
    "description": "Adjust setting technique to compensate for wind conditions. Modify arc, speed, and contact point based on wind direction and strength.",
    "slug": "set-with-wind",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "Short set",
    "discipline": "Set",
    "description": "Deliver a quick, low set close to the net for fast attacks. Requires precise timing with the hitter and minimal ball travel time.",
    "slug": "short-set",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "Back set in emergency",
    "discipline": "Set",
    "description": "Execute back sets under pressure or from difficult positions. Essential skill for when forward sets are not possible due to ball trajectory or position.",
    "slug": "back-set-in-emergency",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "Nike position",
    "discipline": "Attack",
    "description": "Adopt the hitting position with arms extended overhead resembling the Nike logo. This ready position allows for quick arm swing initiation and maximum reach.",
    "slug": "nike-position",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "Rotation of arms and body",
    "discipline": "Attack",
    "description": "Generate hitting power through coordinated body rotation. Start from hips, transfer through torso, and finish with arm whip for maximum velocity.",
    "slug": "rotation-of-arms-and-body",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "Position on the right",
    "discipline": "Attack",
    "description": "Establish optimal hitting position on the right side of the court. Adjust approach angle and timing based on set location and blocker position.",
    "slug": "position-on-the-right",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "Position on the left",
    "discipline": "Attack",
    "description": "Establish optimal hitting position on the left side of the court. Mirror right-side techniques while accounting for different approach angles.",
    "slug": "position-on-the-left",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "Steps to hit",
    "discipline": "Attack",
    "description": "Execute the proper 3-step or 4-step approach for hitting. Left-right-left for right-handed hitters, building momentum and timing with the set.",
    "slug": "steps-to-hit",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "Cross",
    "discipline": "Attack",
    "description": "Hit the ball diagonally across the court to the opposite corner. Effective for avoiding blockers and exploiting open court areas.",
    "slug": "cross",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "High line",
    "discipline": "Attack",
    "description": "Hit the ball down the line with high trajectory. This shot goes over the block and lands deep in the court near the sideline.",
    "slug": "high-line",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "Short cut",
    "discipline": "Attack",
    "description": "Execute a sharp angle shot that lands short and inside the block. Requires wrist snap and precise hand control to cut the ball at extreme angles.",
    "slug": "short-cut",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "Drop shot",
    "discipline": "Attack",
    "description": "Use a soft touch shot that drops just over the block into open court. Deceptive technique that catches defenders off guard when they expect a hard hit.",
    "slug": "drop-shot",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "Rainbow",
    "discipline": "Attack",
    "description": "Hit the ball with extreme arc that goes high over the block and drops steeply into the back court. Effective against tight net coverage.",
    "slug": "rainbow",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "Poke",
    "discipline": "Attack",
    "description": "Use finger tip contact to softly place the ball over the block into open areas. Requires excellent touch and timing for controlled placement.",
    "slug": "poke-2",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "Challenge the block",
    "discipline": "Attack",
    "description": "Intentionally hit into the block to create deflections or tool the block. Aim for the outside hand to redirect balls out of bounds off the blocker.",
    "slug": "challenge-the-block",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "Fake the moves",
    "discipline": "Attack",
    "description": "Use deceptive body movements and arm actions to misdirect blockers. Show one shot direction then execute another to create hitting lanes.",
    "slug": "fake-the-moves",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "Short set",
    "discipline": "Attack",
    "description": "Hit quick sets that travel minimal distance from setter. Requires fast approach timing and compact swing for effective execution.",
    "slug": "short-set-2",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "Hit on second",
    "discipline": "Attack",
    "description": "Attack the ball on the second contact instead of setting. Surprise tactic that catches opponents before they can set up their block.",
    "slug": "hit-on-second",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "Ball too close to the net",
    "discipline": "Attack",
    "description": "Handle sets that are tight to the net. Use open hand technique to push or roll the ball over while avoiding net violations.",
    "slug": "ball-too-close-to-the-net",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "Signs",
    "discipline": "Block",
    "description": "Communicate blocking intentions and coverage with partner through hand signals behind the back. Signals indicate line, cross, or peel coverage.",
    "slug": "signs",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "Foot work",
    "discipline": "Block",
    "description": "Use proper footwork for blocking approach and lateral movement. Shuffle steps and crossover techniques to position at the net efficiently.",
    "slug": "foot-work-2",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "Peel - Hard driven",
    "discipline": "Block",
    "description": "Step away from the net to defend hard-driven balls that go past the block. Quick reaction and transition from blocking to defensive stance.",
    "slug": "peel-hard-driven",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "Peel - Short",
    "discipline": "Block",
    "description": "Move off the net to cover short shots and drops that fall just over the block. Requires reading the hitter early and quick first step.",
    "slug": "peel-short",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "Peel - Long",
    "discipline": "Block",
    "description": "Transition from blocking position to defend deep shots that go over the block. Backpedal and get behind the ball for controlled defensive play.",
    "slug": "peel-long",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "Block line",
    "discipline": "Block",
    "description": "Position the block to cover the line shot, forcing the hitter to go cross-court. Outside hand aligns with the sideline to seal off the angle.",
    "slug": "block-line",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "Block cross",
    "discipline": "Block",
    "description": "Position the block to cover cross-court shots, forcing the hitter down the line. Inside hand covers the middle, outside hand seals the cross-court angle.",
    "slug": "block-cross",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "Serve and go to block",
    "discipline": "Block",
    "description": "Transition from serving to blocking position immediately after contact. Quick movement up to the net to establish the block against the return.",
    "slug": "serve-and-go-to-block",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "Ball in the back after block",
    "discipline": "Block",
    "description": "Defend balls that deflect off the block into the back court. Read the deflection angle and position for controlled defensive play.",
    "slug": "ball-in-the-back-after-block",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "How to turn after block",
    "discipline": "Block",
    "description": "Execute proper body rotation after landing from a block to prepare for the next play. Quick transition from blocking stance to defensive or attacking readiness.",
    "slug": "how-to-turn-after-block",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "Position of serve wind/sun",
    "discipline": "Serve",
    "description": "Adjust serving position based on wind direction and sun location. Use wind at your back for power, avoid serving into the sun, and account for drift.",
    "slug": "position-of-serve-wind-sun",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "Arm swing",
    "discipline": "Serve",
    "description": "Execute proper serving arm motion with high elbow, full extension, and wrist snap. Generate power from shoulder rotation and follow through toward target.",
    "slug": "arm-swing",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "Short",
    "discipline": "Serve",
    "description": "Execute a serve that lands just over the net in the front court. Forces receivers to move forward quickly and can disrupt their attacking rhythm.",
    "slug": "short",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "Long",
    "discipline": "Serve",
    "description": "Serve deep to the back of the court to push receivers away from the net. Creates difficulty for quick attacks and can force free balls back.",
    "slug": "long",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "Direction",
    "discipline": "Serve",
    "description": "Control serve placement to target specific court areas. Aim for weak receivers, seams between players, or corners to maximize serving effectiveness.",
    "slug": "direction",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "Jump float",
    "discipline": "Serve",
    "description": "Execute a jump serve with minimal spin for unpredictable ball movement. The floating action makes it difficult for receivers to judge trajectory.",
    "slug": "jump-float",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "Jump serve",
    "discipline": "Serve",
    "description": "Perform an aggressive jump serve with topspin for power and downward trajectory. Requires precise timing, approach, and contact point for consistency.",
    "slug": "jump-serve",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "Read other players body",
    "discipline": "Strategy",
    "description": "Observe opponent body language, foot positioning, and arm movements to anticipate their next play. Early reading provides crucial reaction time advantages.",
    "slug": "read-other-players-body-2",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "Test",
    "discipline": "Attack",
    "description": "test",
    "slug": "test",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "Test Skill for Logging",
    "discipline": "Attack",
    "description": nil,
    "slug": "test-skill-for-logging",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "Test 2",
    "discipline": "Attack",
    "description": "test 2",
    "slug": "test-2",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "Always play close",
    "discipline": "Attack",
    "description": "afdsafsdaf",
    "slug": "always-play-close-2",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  },
  {
    "title": "Test of Attack",
    "discipline": "Attack",
    "description": "lkjkljl",
    "slug": "test-of-attack",
    "visibility": "shared",
    "status": "published",
    "published_at": nil
  }
].freeze
DRILLS_DATA = [
  {
    "title": "Setting Practice",
    "setup_instructions": "Partners 5m apart",
    "ideal_num_players": 2,
    "difficulty_level": "beginner",
    "training_stage": "beginning",
    "min_players": 2,
    "max_players": 2,
    "slug": "setting-practice",
    "definition": {},
    "visibility": "shared",
    "status": "published",
    "published_at": "2026-11-01T10:31:59Z",
    "approved_at": nil,
    "skills": [
      {
        "title": "Hand Setting",
        "slug": "hand-setting"
      }
    ]
  },
  {
    "title": "Target Serving Analysis",
    "setup_instructions": "Place targets in each corner of the court. Server practices identifying and serving to the weakest receiver. Partners provide feedback on target selection.",
    "ideal_num_players": 2,
    "difficulty_level": "intermediate",
    "training_stage": "beginning",
    "min_players": 2,
    "max_players": 2,
    "slug": "target-serving-analysis",
    "definition": {},
    "visibility": "shared",
    "status": "published",
    "published_at": "2026-11-01T10:31:59Z",
    "approved_at": nil,
    "skills": [
      {
        "title": "Which side to choose",
        "slug": "which-side-to-choose"
      },
      {
        "title": "Who to serve on. When serve middle.",
        "slug": "who-to-serve-on-when-serve-middle"
      }
    ]
  },
  {
    "title": "Court Positioning Drill",
    "setup_instructions": "Coach calls out game situations. Players must quickly move to correct court positions and communicate coverage. Emphasize staying close together.",
    "ideal_num_players": 2,
    "difficulty_level": "beginner",
    "training_stage": "beginning",
    "min_players": 2,
    "max_players": 2,
    "slug": "court-positioning-drill",
    "definition": {},
    "visibility": "shared",
    "status": "published",
    "published_at": "2026-11-01T10:31:59Z",
    "approved_at": nil,
    "skills": [
      {
        "title": "Hand Setting",
        "slug": "hand-setting"
      },
      {
        "title": "Who is middle",
        "slug": "who-is-middle"
      },
      {
        "title": "Court position (always close to each other)",
        "slug": "court-position-always-close-to-each-other"
      },
      {
        "title": "Always play close",
        "slug": "always-play-close-2"
      }
    ]
  },
  {
    "title": "Communication Practice",
    "setup_instructions": "During practice rallies, players must call out every play loudly. Coach evaluates quality and timing of verbal cues between partners.",
    "ideal_num_players": 2,
    "difficulty_level": "beginner",
    "training_stage": "beginning",
    "min_players": 2,
    "max_players": 2,
    "slug": "communication-practice",
    "definition": {},
    "visibility": "shared",
    "status": "published",
    "published_at": "2026-11-01T10:31:59Z",
    "approved_at": nil,
    "skills": [
      {
        "title": "Hand Setting",
        "slug": "hand-setting"
      },
      {
        "title": "Always talk. What to talk. Who talks",
        "slug": "always-talk-what-to-talk-who-talks"
      },
      {
        "title": "Always play close",
        "slug": "always-play-close-2"
      }
    ]
  },
  {
    "title": "Wind Reading Exercise",
    "setup_instructions": "Practice serving and hitting with attention to wind direction. Adjust technique based on conditions and discuss strategy adaptations between plays.",
    "ideal_num_players": 2,
    "difficulty_level": "intermediate",
    "training_stage": "beginning",
    "min_players": 2,
    "max_players": 2,
    "slug": "wind-reading-exercise",
    "definition": {},
    "visibility": "shared",
    "status": "published",
    "published_at": "2026-11-01T10:31:59Z",
    "approved_at": nil,
    "skills": [
      {
        "title": "How to use the wind and sun in your favor",
        "slug": "how-to-use-the-wind-and-sun-in-your-favor"
      }
    ]
  },
  {
    "title": "Serve Receive Positioning",
    "setup_instructions": "Server serves from various positions. Receiver adjusts starting position based on server tendencies and practices optimal platform angle.",
    "ideal_num_players": 2,
    "difficulty_level": "beginner",
    "training_stage": "beginning",
    "min_players": 2,
    "max_players": 2,
    "slug": "serve-receive-positioning",
    "definition": {},
    "visibility": "shared",
    "status": "published",
    "published_at": "2026-11-01T10:31:59Z",
    "approved_at": nil,
    "skills": [
      {
        "title": "Position to serve receive",
        "slug": "position-to-serve-receive"
      }
    ]
  },
  {
    "title": "Lateral Movement Defence",
    "setup_instructions": "Coach hits balls to alternating sides. Defender practices lateral shuffle and shoulder rotation to get behind each ball with proper platform.",
    "ideal_num_players": 2,
    "difficulty_level": "beginner",
    "training_stage": "beginning",
    "min_players": 2,
    "max_players": 2,
    "slug": "lateral-movement-defence",
    "definition": {},
    "visibility": "shared",
    "status": "published",
    "published_at": "2026-11-01T10:31:59Z",
    "approved_at": nil,
    "skills": [
      {
        "title": "Lateral/shoulder",
        "slug": "lateral-shoulder"
      },
      {
        "title": "Lateral moving",
        "slug": "lateral-moving"
      }
    ]
  },
  {
    "title": "High Ball Defence",
    "setup_instructions": "Coach hits high arcing balls from the opposite end. Defender practices positioning behind the ball and using controlled platform for accurate digs.",
    "ideal_num_players": 2,
    "difficulty_level": "beginner",
    "training_stage": "beginning",
    "min_players": 2,
    "max_players": 2,
    "slug": "high-ball-defence",
    "definition": {},
    "visibility": "shared",
    "status": "published",
    "published_at": "2026-11-01T10:31:59Z",
    "approved_at": nil,
    "skills": [
      {
        "title": "Behind the ball",
        "slug": "behind-the-ball"
      },
      {
        "title": "Lateral high",
        "slug": "lateral-high"
      }
    ]
  },
  {
    "title": "Tomahawk Practice",
    "setup_instructions": "Coach hits hard-driven balls at close range. Defender practices overhead tomahawk technique for emergency defensive plays.",
    "ideal_num_players": 2,
    "difficulty_level": "intermediate",
    "training_stage": "beginning",
    "min_players": 2,
    "max_players": 2,
    "slug": "tomahawk-practice",
    "definition": {},
    "visibility": "shared",
    "status": "published",
    "published_at": "2026-11-01T10:31:59Z",
    "approved_at": nil,
    "skills": [
      {
        "title": "Tomahawk",
        "slug": "tomahawk"
      }
    ]
  },
  {
    "title": "Transition Attack Drill",
    "setup_instructions": "Defender digs a controlled ball, then immediately transitions to attacking position. Setter sets to transitioning player for immediate attack.",
    "ideal_num_players": 2,
    "difficulty_level": "intermediate",
    "training_stage": "beginning",
    "min_players": 2,
    "max_players": 2,
    "slug": "transition-attack-drill",
    "definition": {},
    "visibility": "shared",
    "status": "published",
    "published_at": "2026-11-01T10:31:59Z",
    "approved_at": nil,
    "skills": [
      {
        "title": "Transition to attack",
        "slug": "transition-to-attack"
      }
    ]
  },
  {
    "title": "Hard Driven Ball Dig",
    "setup_instructions": "Attacker hits hard-driven balls at defender. Defender practices low platform technique and body control to absorb pace and redirect to target.",
    "ideal_num_players": 2,
    "difficulty_level": "intermediate",
    "training_stage": "beginning",
    "min_players": 2,
    "max_players": 2,
    "slug": "hard-driven-ball-dig",
    "definition": {},
    "visibility": "shared",
    "status": "published",
    "published_at": "2026-11-01T10:31:59Z",
    "approved_at": nil,
    "skills": [
      {
        "title": "Saving hard driven hit - dig",
        "slug": "saving-hard-driven-hit-dig"
      },
      {
        "title": "Saving hard driven hit - high",
        "slug": "saving-hard-driven-hit-high"
      }
    ]
  },
  {
    "title": "Gator Technique Drill",
    "setup_instructions": "Coach hits hard balls at close range. Defender practices gator dig with hands together and rolling motion for controlled upward redirection.",
    "ideal_num_players": 2,
    "difficulty_level": "advanced",
    "training_stage": "beginning",
    "min_players": 2,
    "max_players": 2,
    "slug": "gator-technique-drill",
    "definition": {},
    "visibility": "shared",
    "status": "published",
    "published_at": "2026-11-01T10:31:59Z",
    "approved_at": nil,
    "skills": [
      {
        "title": "Gator",
        "slug": "gator"
      }
    ]
  },
  {
    "title": "Net Ball Recovery",
    "setup_instructions": "Coach tips balls into the net from various angles. Defender practices quick reaction to unpredictable bounces and recovery plays.",
    "ideal_num_players": 2,
    "difficulty_level": "intermediate",
    "training_stage": "beginning",
    "min_players": 2,
    "max_players": 2,
    "slug": "net-ball-recovery",
    "definition": {},
    "visibility": "shared",
    "status": "published",
    "published_at": "2026-11-01T10:31:59Z",
    "approved_at": nil,
    "skills": [
      {
        "title": "Saving after ball on the net",
        "slug": "saving-after-ball-on-the-net"
      }
    ]
  },
  {
    "title": "Wall Setting Repetitions",
    "setup_instructions": "Player sets against a wall at varying distances. Focus on hand position, finger spread, and consistent contact point for accuracy.",
    "ideal_num_players": 1,
    "difficulty_level": "beginner",
    "training_stage": "beginning",
    "min_players": 1,
    "max_players": 1,
    "slug": "wall-setting-repetitions",
    "definition": {},
    "visibility": "shared",
    "status": "published",
    "published_at": "2026-11-01T10:31:59Z",
    "approved_at": nil,
    "skills": [
      {
        "title": "Handset",
        "slug": "handset"
      },
      {
        "title": "Foot work",
        "slug": "foot-work"
      }
    ]
  },
  {
    "title": "Back Set Practice",
    "setup_instructions": "Setter practices back sets to a target behind them. Focus on body rotation, arm extension, and consistent release point for accuracy.",
    "ideal_num_players": 2,
    "difficulty_level": "intermediate",
    "training_stage": "beginning",
    "min_players": 2,
    "max_players": 2,
    "slug": "back-set-practice",
    "definition": {
      "side": {
        "grid": {
          "rows": 20,
          "columns": 10
        }
      },
      "view": {
        "orientation": "lateral"
      },
      "balls": [
        {
          "id": "b1",
          "type": "volleyball"
        }
      ],
      "steps": [
        {
          "id": "step_1",
          "balls": [
            {
              "id": "b1",
              "active": true,
              "location": {
                "x": 5,
                "y": 1,
                "side": "side_1"
              }
            }
          ],
          "actions": [
            {
              "action": {
                "type": "serve",
                "description": "Serve deep toward receiver."
              },
              "participant_id": "p1"
            }
          ],
          "objects": [],
          "description": "Server starts behind the baseline and serves toward the receiving team.",
          "participants": [
            {
              "id": "p1",
              "active": true,
              "location": {
                "x": 5,
                "y": 1,
                "side": "side_1"
              }
            },
            {
              "id": "p2",
              "active": true,
              "location": {
                "x": 3,
                "y": 15,
                "side": "side_2"
              }
            },
            {
              "id": "p3",
              "active": true,
              "location": {
                "x": 7,
                "y": 15,
                "side": "side_2"
              }
            },
            {
              "id": "p4",
              "active": false,
              "location": {
                "x": 5,
                "y": 18,
                "side": "side_2"
              }
            }
          ],
          "ball_movements": [
            {
              "to": {
                "x": 3,
                "y": 15,
                "side": "side_2"
              },
              "from": {
                "x": 5,
                "y": 1,
                "side": "side_1"
              },
              "ball_id": "b1",
              "description": "Ball travels from server toward receiver."
            }
          ],
          "object_movements": [],
          "participant_movements": []
        },
        {
          "id": "step_2",
          "balls": [
            {
              "id": "b1",
              "active": true,
              "location": {
                "x": 3,
                "y": 15,
                "side": "side_2"
              }
            }
          ],
          "actions": [
            {
              "action": {
                "type": "receive",
                "description": "Receive with controlled platform toward setter."
              },
              "participant_id": "p2"
            },
            {
              "action": {
                "type": "set",
                "description": "Move toward the ball and prepare to set."
              },
              "participant_id": "p3"
            }
          ],
          "objects": [],
          "description": "Receiver moves into position and passes toward the setter.",
          "participants": [
            {
              "id": "p1",
              "active": false,
              "location": {
                "x": 5,
                "y": 1,
                "side": "side_1"
              }
            },
            {
              "id": "p2",
              "active": true,
              "location": {
                "x": 3,
                "y": 15,
                "side": "side_2"
              }
            },
            {
              "id": "p3",
              "active": true,
              "location": {
                "x": 7,
                "y": 15,
                "side": "side_2"
              }
            }
          ],
          "ball_movements": [
            {
              "to": {
                "x": 5,
                "y": 12,
                "side": "side_2"
              },
              "from": {
                "x": 3,
                "y": 15,
                "side": "side_2"
              },
              "ball_id": "b1",
              "description": "Pass travels toward setter."
            }
          ],
          "object_movements": [],
          "participant_movements": [
            {
              "to": {
                "x": 5,
                "y": 12,
                "side": "side_2"
              },
              "from": {
                "x": 7,
                "y": 15,
                "side": "side_2"
              },
              "description": "Setter moves toward the anticipated pass.",
              "participant_id": "p3"
            }
          ]
        }
      ],
      "objects": [],
      "version": 1,
      "description": "Serve-and-attack drill: P1 tosses over the net, P2 passes, P3 sets, P2 hits hard-driven line. P1 crosses to block or peel.",
      "participants": [
        {
          "id": "p1",
          "role": "server",
          "type": "player"
        },
        {
          "id": "p2",
          "role": "receiver",
          "type": "player"
        },
        {
          "id": "p3",
          "role": "setter",
          "type": "player"
        },
        {
          "id": "p4",
          "role": "defender",
          "type": "player"
        },
        {
          "id": "p5",
          "role": "attacker",
          "type": "player"
        }
      ]
    },
    "visibility": "shared",
    "status": "published",
    "published_at": "2026-11-01T10:31:59Z",
    "approved_at": nil,
    "skills": [
      {
        "title": "Hand Setting",
        "slug": "hand-setting"
      },
      {
        "title": "Back set",
        "slug": "back-set"
      },
      {
        "title": "Always play close",
        "slug": "always-play-close-2"
      }
    ]
  },
  {
    "title": "Deep Court Setting",
    "setup_instructions": "Setter positioned deep in court practices setting to attackers. Focus on higher arc and stronger arm action to create effective attack opportunities.",
    "ideal_num_players": 2,
    "difficulty_level": "intermediate",
    "training_stage": "beginning",
    "min_players": 2,
    "max_players": 2,
    "slug": "deep-court-setting",
    "definition": {},
    "visibility": "shared",
    "status": "published",
    "published_at": "2026-11-01T10:31:59Z",
    "approved_at": nil,
    "skills": [
      {
        "title": "From back of the court",
        "slug": "from-back-of-the-court"
      }
    ]
  },
  {
    "title": "Short Set Timing",
    "setup_instructions": "Setter and hitter practice quick combination plays. Focus on minimal ball travel time and precise timing for fast attacks.",
    "ideal_num_players": 2,
    "difficulty_level": "advanced",
    "training_stage": "beginning",
    "min_players": 2,
    "max_players": 2,
    "slug": "short-set-timing",
    "definition": {},
    "visibility": "shared",
    "status": "published",
    "published_at": "2026-11-01T10:31:59Z",
    "approved_at": nil,
    "skills": [
      {
        "title": "Short set",
        "slug": "short-set"
      }
    ]
  },
  {
    "title": "Emergency Back Set",
    "setup_instructions": "Coach feeds difficult balls that require back setting. Setter practices technique under pressure for emergency back set situations.",
    "ideal_num_players": 2,
    "difficulty_level": "advanced",
    "training_stage": "beginning",
    "min_players": 2,
    "max_players": 2,
    "slug": "emergency-back-set",
    "definition": {},
    "visibility": "shared",
    "status": "published",
    "published_at": "2026-11-01T10:31:59Z",
    "approved_at": nil,
    "skills": [
      {
        "title": "Back set in emergency",
        "slug": "back-set-in-emergency"
      }
    ]
  },
  {
    "title": "Wind Setting Adjustment",
    "setup_instructions": "Practice setting in windy conditions. Adjust arc, speed, and contact point to compensate for wind effects on ball trajectory.",
    "ideal_num_players": 2,
    "difficulty_level": "intermediate",
    "training_stage": "beginning",
    "min_players": 2,
    "max_players": 2,
    "slug": "wind-setting-adjustment",
    "definition": {},
    "visibility": "shared",
    "status": "published",
    "published_at": "2026-11-01T10:31:59Z",
    "approved_at": nil,
    "skills": [
      {
        "title": "Set with wind",
        "slug": "set-with-wind"
      }
    ]
  },
  {
    "title": "Approach and Hit Timing",
    "setup_instructions": "Practice the 3-step approach with proper timing to the set. Focus on building momentum and connecting with the ball at peak height.",
    "ideal_num_players": 2,
    "difficulty_level": "beginner",
    "training_stage": "beginning",
    "min_players": 2,
    "max_players": 2,
    "slug": "approach-and-hit-timing",
    "definition": {
      "side": {
        "grid": {
          "rows": 20,
          "columns": 10
        }
      },
      "view": {
        "orientation": "top_down"
      },
      "balls": [
        {
          "id": "b1",
          "type": "volleyball"
        }
      ],
      "steps": [
        {
          "id": "step_1",
          "balls": [
            {
              "id": "b1",
              "active": true,
              "location": {
                "x": 5,
                "y": 1,
                "side": "side_1"
              }
            }
          ],
          "actions": [
            {
              "action": {
                "type": "serve",
                "description": "Serve deep toward receiver."
              },
              "participant_id": "p1"
            },
            {
              "action": {
                "type": "receive",
                "description": "P1 Receives"
              },
              "participant_id": "p1"
            },
            {
              "action": {
                "type": "pass",
                "description": "P1 Passes"
              },
              "participant_id": "p1"
            }
          ],
          "objects": [
            {
              "id": "O1",
              "active": true,
              "location": {
                "x": 8,
                "y": 4,
                "side": "side_1"
              }
            }
          ],
          "annotations": [
            {
              "id": "text_1",
              "bold": false,
              "text": "Attack here",
              "type": "text",
              "align": "left",
              "width": 0.28,
              "border": false,
              "height": 0.16,
              "italic": false,
              "location": {
                "x": 6.3231,
                "y": 11.4113,
                "side": "side_1"
              },
              "font_size": 14,
              "background": false
            }
          ],
          "description": "Server starts behind the baseline and serves toward the receiving team.",
          "participants": [
            {
              "id": "p1",
              "active": true,
              "location": {
                "x": 5,
                "y": 1,
                "side": "side_1"
              }
            },
            {
              "id": "p2",
              "active": true,
              "location": {
                "x": 3,
                "y": 15,
                "side": "side_2"
              }
            },
            {
              "id": "p3",
              "active": true,
              "location": {
                "x": 7,
                "y": 15,
                "side": "side_2"
              }
            },
            {
              "id": "p4",
              "active": false,
              "location": {
                "x": 5,
                "y": 18,
                "side": "side_2"
              }
            }
          ],
          "ball_movements": [
            {
              "to": {
                "x": 2,
                "y": 9,
                "side": "side_2"
              },
              "from": {
                "x": 5,
                "y": 1,
                "side": "side_1"
              },
              "ball_id": "b1",
              "description": "Ball travels from server toward receiver."
            }
          ],
          "object_movements": [
            {
              "to": {
                "x": 8,
                "y": 11,
                "side": "side_1"
              },
              "from": {
                "x": 8,
                "y": 4,
                "side": "side_1"
              },
              "object_id": "O1"
            }
          ],
          "participant_movements": [
            {
              "to": {
                "x": 7,
                "y": 12,
                "side": "side_1"
              },
              "from": {
                "x": 5,
                "y": 1,
                "side": "side_1"
              },
              "participant_id": "p1"
            },
            {
              "to": {
                "x": 2,
                "y": 9,
                "side": "side_2"
              },
              "from": {
                "x": 3,
                "y": 15,
                "side": "side_2"
              },
              "participant_id": "p2"
            },
            {
              "to": {
                "x": 7,
                "y": 10,
                "side": "side_2"
              },
              "from": {
                "x": 7,
                "y": 15,
                "side": "side_2"
              },
              "participant_id": "p3"
            }
          ]
        },
        {
          "id": "step_2",
          "balls": [
            {
              "id": "b1",
              "active": true,
              "location": {
                "x": 2,
                "y": 9,
                "side": "side_2"
              }
            }
          ],
          "actions": [
            {
              "action": {
                "type": "receive",
                "description": "Receive with controlled platform toward setter."
              },
              "participant_id": "p2"
            },
            {
              "action": {
                "type": "set",
                "description": "Move toward the ball and prepare to set."
              },
              "participant_id": "p3"
            }
          ],
          "objects": [
            {
              "id": "O1",
              "active": true,
              "location": {
                "x": 8,
                "y": 11,
                "side": "side_1"
              }
            }
          ],
          "description": "Receiver moves into position and passes toward the setter.",
          "participants": [
            {
              "id": "p1",
              "active": true,
              "location": {
                "x": 7,
                "y": 12,
                "side": "side_1"
              }
            },
            {
              "id": "p2",
              "active": true,
              "location": {
                "x": 2,
                "y": 9,
                "side": "side_2"
              }
            },
            {
              "id": "p3",
              "active": true,
              "location": {
                "x": 7,
                "y": 10,
                "side": "side_2"
              }
            },
            {
              "id": "p4",
              "active": true,
              "location": {
                "x": 4,
                "y": 8,
                "side": "side_1"
              }
            }
          ],
          "ball_movements": [
            {
              "to": {
                "x": 7,
                "y": 16,
                "side": "side_2"
              },
              "from": {
                "x": 2,
                "y": 9,
                "side": "side_2"
              },
              "ball_id": "b1"
            }
          ],
          "object_movements": [],
          "participant_movements": [
            {
              "to": {
                "x": 3,
                "y": 15,
                "side": "side_2"
              },
              "from": {
                "x": 2,
                "y": 9,
                "side": "side_2"
              },
              "participant_id": "p2"
            },
            {
              "to": {
                "x": 7,
                "y": 15,
                "side": "side_2"
              },
              "from": {
                "x": 7,
                "y": 10,
                "side": "side_2"
              },
              "participant_id": "p3"
            },
            {
              "to": {
                "x": 6,
                "y": 17,
                "side": "side_1"
              },
              "from": {
                "x": 4,
                "y": 8,
                "side": "side_1"
              },
              "participant_id": "p4"
            }
          ]
        },
        {
          "id": "S1",
          "balls": [
            {
              "id": "b1",
              "active": true,
              "location": {
                "x": 7,
                "y": 16,
                "side": "side_2"
              }
            }
          ],
          "actions": [],
          "objects": [],
          "participants": [
            {
              "id": "p2",
              "active": true,
              "location": {
                "x": 3,
                "y": 15,
                "side": "side_2"
              }
            },
            {
              "id": "p3",
              "active": true,
              "location": {
                "x": 7,
                "y": 15,
                "side": "side_2"
              }
            },
            {
              "id": "p4",
              "active": true,
              "location": {
                "x": 6,
                "y": 17,
                "side": "side_1"
              }
            }
          ],
          "ball_movements": [],
          "object_movements": [],
          "participant_movements": []
        }
      ],
      "objects": [
        {
          "id": "O1",
          "type": "cone"
        },
        {
          "id": "O2",
          "type": "bench"
        }
      ],
      "version": 1,
      "description": "Serve-and-attack drill: P1 tosses over the net, P2 passes, P3 sets, P2 hits hard-driven line. P1 crosses to block or peel.",
      "participants": [
        {
          "id": "p1",
          "role": "server",
          "type": "player"
        },
        {
          "id": "p2",
          "role": "receiver",
          "type": "player"
        },
        {
          "id": "p3",
          "role": "setter",
          "type": "player"
        },
        {
          "id": "p4",
          "role": "defender",
          "type": "player"
        }
      ]
    },
    "visibility": "shared",
    "status": "published",
    "published_at": "2026-11-01T10:31:59Z",
    "approved_at": nil,
    "skills": [
      {
        "title": "Hand Setting",
        "slug": "hand-setting"
      },
      {
        "title": "Nike position",
        "slug": "nike-position"
      },
      {
        "title": "Steps to hit",
        "slug": "steps-to-hit"
      },
      {
        "title": "Always play close",
        "slug": "always-play-close-2"
      }
    ]
  },
  {
    "title": "Cross Court Hitting",
    "setup_instructions": "Setter sets to attacker who practices hitting diagonally across court. Focus on arm angle and wrist control for accurate placement.",
    "ideal_num_players": 2,
    "difficulty_level": "intermediate",
    "training_stage": "beginning",
    "min_players": 2,
    "max_players": 2,
    "slug": "cross-court-hitting",
    "definition": {
      "side": {
        "grid": {
          "rows": 4,
          "columns": 5
        }
      },
      "balls": [],
      "steps": [
        {
          "id": "S1",
          "balls": [],
          "actions": [],
          "objects": [],
          "participants": [],
          "ball_movements": [],
          "object_movements": [],
          "participant_movements": []
        }
      ],
      "objects": [],
      "version": 1,
      "participants": []
    },
    "visibility": "shared",
    "status": "published",
    "published_at": "2026-11-01T10:31:59Z",
    "approved_at": nil,
    "skills": [
      {
        "title": "Hand Setting",
        "slug": "hand-setting"
      },
      {
        "title": "Rotation of arms and body",
        "slug": "rotation-of-arms-and-body"
      },
      {
        "title": "Cross",
        "slug": "cross"
      },
      {
        "title": "Always play close",
        "slug": "always-play-close-2"
      }
    ]
  },
  {
    "title": "Line Shot Practice",
    "setup_instructions": "Attacker practices hitting down the line with high trajectory. Focus on going over the block and landing deep near the sideline.",
    "ideal_num_players": 2,
    "difficulty_level": "intermediate",
    "training_stage": "beginning",
    "min_players": 2,
    "max_players": 2,
    "slug": "line-shot-practice",
    "definition": {},
    "visibility": "shared",
    "status": "published",
    "published_at": "2026-11-01T10:31:59Z",
    "approved_at": nil,
    "skills": [
      {
        "title": "Hand Setting",
        "slug": "hand-setting"
      },
      {
        "title": "High line",
        "slug": "high-line"
      },
      {
        "title": "Always play close",
        "slug": "always-play-close-2"
      }
    ]
  },
  {
    "title": "Cut Shot Technique",
    "setup_instructions": "Attacker practices short cut shots at sharp angles. Focus on wrist snap and hand control to cut the ball at extreme angles.",
    "ideal_num_players": 2,
    "difficulty_level": "advanced",
    "training_stage": "beginning",
    "min_players": 2,
    "max_players": 2,
    "slug": "cut-shot-technique",
    "definition": {},
    "visibility": "shared",
    "status": "published",
    "published_at": "2026-11-01T10:31:59Z",
    "approved_at": nil,
    "skills": [
      {
        "title": "Hand Setting",
        "slug": "hand-setting"
      },
      {
        "title": "Short cut",
        "slug": "short-cut"
      },
      {
        "title": "Always play close",
        "slug": "always-play-close-2"
      }
    ]
  },
  {
    "title": "Drop Shot Deception",
    "setup_instructions": "Attacker shows full hitting motion then executes soft drop shot. Focus on deception and touch to place ball just over the block.",
    "ideal_num_players": 2,
    "difficulty_level": "advanced",
    "training_stage": "beginning",
    "min_players": 2,
    "max_players": 2,
    "slug": "drop-shot-deception",
    "definition": {},
    "visibility": "shared",
    "status": "published",
    "published_at": "2026-11-01T10:31:59Z",
    "approved_at": nil,
    "skills": [
      {
        "title": "Hand Setting",
        "slug": "hand-setting"
      },
      {
        "title": "Drop shot",
        "slug": "drop-shot"
      },
      {
        "title": "Always play close",
        "slug": "always-play-close-2"
      }
    ]
  },
  {
    "title": "Block Tooling Drill",
    "setup_instructions": "With a blocker at net, attacker practices hitting off the outside hand. Aim for deflections out of bounds off the blocker.",
    "ideal_num_players": 3,
    "difficulty_level": "advanced",
    "training_stage": "beginning",
    "min_players": 2,
    "max_players": 4,
    "slug": "block-tooling-drill",
    "definition": {},
    "visibility": "shared",
    "status": "published",
    "published_at": "2026-11-01T10:31:59Z",
    "approved_at": nil,
    "skills": [
      {
        "title": "Hand Setting",
        "slug": "hand-setting"
      },
      {
        "title": "Challenge the block",
        "slug": "challenge-the-block"
      },
      {
        "title": "Always play close",
        "slug": "always-play-close-2"
      }
    ]
  },
  {
    "title": "Quick Set Attack",
    "setup_instructions": "Setter delivers short sets for immediate attack. Hitter practices fast approach timing and compact swing for quick combination plays.",
    "ideal_num_players": 2,
    "difficulty_level": "advanced",
    "training_stage": "beginning",
    "min_players": 2,
    "max_players": 2,
    "slug": "quick-set-attack",
    "definition": {},
    "visibility": "shared",
    "status": "published",
    "published_at": "2026-11-01T10:31:59Z",
    "approved_at": nil,
    "skills": [
      {
        "title": "Hand Setting",
        "slug": "hand-setting"
      },
      {
        "title": "Short set",
        "slug": "short-set"
      },
      {
        "title": "Hit on second",
        "slug": "hit-on-second"
      },
      {
        "title": "Always play close",
        "slug": "always-play-close-2"
      }
    ]
  },
  {
    "title": "Tight Net Ball Handling",
    "setup_instructions": "Setter delivers sets tight to the net. Attacker practices open hand technique to push or roll balls over while avoiding net violations.",
    "ideal_num_players": 2,
    "difficulty_level": "advanced",
    "training_stage": "beginning",
    "min_players": 2,
    "max_players": 2,
    "slug": "tight-net-ball-handling",
    "definition": {},
    "visibility": "shared",
    "status": "published",
    "published_at": "2026-11-01T10:31:59Z",
    "approved_at": nil,
    "skills": [
      {
        "title": "Hand Setting",
        "slug": "hand-setting"
      },
      {
        "title": "Ball too close to the net",
        "slug": "ball-too-close-to-the-net"
      },
      {
        "title": "Block cross",
        "slug": "block-cross"
      },
      {
        "title": "Short",
        "slug": "short"
      },
      {
        "title": "Always play close",
        "slug": "always-play-close-2"
      }
    ]
  },
  {
    "title": "Block Communication Signals",
    "setup_instructions": "Practice hand signals behind the back to indicate blocking coverage. Partners must read signals and position accordingly before each play.",
    "ideal_num_players": 2,
    "difficulty_level": "beginner",
    "training_stage": "beginning",
    "min_players": 2,
    "max_players": 2,
    "slug": "block-communication-signals",
    "definition": {
      "side": {
        "grid": {
          "rows": 10,
          "columns": 20
        }
      },
      "balls": [
        {
          "id": "B1",
          "type": "volleyball"
        },
        {
          "id": "B2",
          "type": "volleyball"
        }
      ],
      "steps": [
        {
          "id": "S1",
          "balls": [
            {
              "id": "B1",
              "active": true,
              "location": {
                "x": 10,
                "y": 1,
                "side": "side_1"
              }
            }
          ],
          "actions": [],
          "objects": [],
          "annotations": [
            {
              "id": "text_1",
              "bold": false,
              "text": "Blocker move to be in front of the passer\n",
              "type": "text",
              "align": "left",
              "width": 0.44,
              "border": false,
              "height": 0.16,
              "italic": false,
              "location": {
                "x": 8.1564,
                "y": 6.879,
                "side": "side_1"
              },
              "font_size": 14,
              "background": false
            },
            {
              "id": "text_2",
              "bold": false,
              "text": "Server moves to middle",
              "type": "text",
              "align": "left",
              "width": 0.35,
              "border": false,
              "height": 0.16,
              "italic": false,
              "location": {
                "x": 2.7564,
                "y": 3.7682,
                "side": "side_1"
              },
              "font_size": 14,
              "background": false
            }
          ],
          "participants": [
            {
              "id": "P1",
              "active": true,
              "location": {
                "x": 10,
                "y": 1,
                "side": "side_1"
              }
            },
            {
              "id": "P2",
              "active": true,
              "location": {
                "x": 10,
                "y": 9,
                "side": "side_1"
              }
            },
            {
              "id": "P3",
              "active": true,
              "location": {
                "x": 5,
                "y": 3,
                "side": "side_2"
              }
            },
            {
              "id": "P4",
              "active": true,
              "location": {
                "x": 15,
                "y": 3,
                "side": "side_2"
              }
            }
          ],
          "ball_movements": [
            {
              "to": {
                "x": 14,
                "y": 4,
                "side": "side_2"
              },
              "from": {
                "x": 10,
                "y": 1,
                "side": "side_1"
              },
              "ball_id": "B1"
            }
          ],
          "object_movements": [],
          "participant_movements": [
            {
              "to": {
                "x": 10,
                "y": 3,
                "side": "side_1"
              },
              "from": {
                "x": 10,
                "y": 1,
                "side": "side_1"
              },
              "participant_id": "P1"
            },
            {
              "to": {
                "x": 13,
                "y": 9,
                "side": "side_1"
              },
              "from": {
                "x": 10,
                "y": 9,
                "side": "side_1"
              },
              "participant_id": "P2"
            },
            {
              "to": {
                "x": 8,
                "y": 6,
                "side": "side_2"
              },
              "from": {
                "x": 5,
                "y": 3,
                "side": "side_2"
              },
              "participant_id": "P3"
            },
            {
              "to": {
                "x": 14,
                "y": 4,
                "side": "side_2"
              },
              "from": {
                "x": 15,
                "y": 3,
                "side": "side_2"
              },
              "participant_id": "P4"
            }
          ]
        },
        {
          "id": "S2",
          "balls": [
            {
              "id": "B1",
              "active": true,
              "location": {
                "x": 14,
                "y": 4,
                "side": "side_2"
              }
            }
          ],
          "actions": [],
          "objects": [],
          "annotations": [
            {
              "id": "text_1",
              "bold": false,
              "text": "Setter moves to set.",
              "type": "text",
              "align": "left",
              "width": 0.28,
              "border": false,
              "height": 0.16,
              "italic": false,
              "location": {
                "x": 3.1307,
                "y": 7.9682,
                "side": "side_2"
              },
              "font_size": 14,
              "background": false
            },
            {
              "id": "text_2",
              "bold": false,
              "text": "Blocker align with hitter.",
              "type": "text",
              "align": "left",
              "width": 0.28,
              "border": false,
              "height": 0.16,
              "italic": false,
              "location": {
                "x": 10.4319,
                "y": 7.1124,
                "side": "side_1"
              },
              "font_size": 14,
              "background": false
            },
            {
              "id": "text_3",
              "bold": false,
              "text": "Hitter positions with body pointed to the right corner.",
              "type": "text",
              "align": "left",
              "width": 0.36,
              "border": false,
              "height": 0.16,
              "italic": false,
              "location": {
                "x": 12.8877,
                "y": 9.0533,
                "side": "side_2"
              },
              "font_size": 12,
              "background": false
            },
            {
              "id": "text_4",
              "bold": false,
              "text": "Defender moves to defend the corner.",
              "type": "text",
              "align": "left",
              "width": 0.46,
              "border": false,
              "height": 0.16,
              "italic": false,
              "location": {
                "x": 4.0117,
                "y": 4.3617,
                "side": "side_1"
              },
              "font_size": 14,
              "background": false
            }
          ],
          "participants": [
            {
              "id": "P1",
              "active": true,
              "location": {
                "x": 10,
                "y": 3,
                "side": "side_1"
              }
            },
            {
              "id": "P2",
              "active": true,
              "location": {
                "x": 13,
                "y": 9,
                "side": "side_1"
              }
            },
            {
              "id": "P3",
              "active": true,
              "location": {
                "x": 8,
                "y": 6,
                "side": "side_2"
              }
            },
            {
              "id": "P4",
              "active": true,
              "location": {
                "x": 14,
                "y": 4,
                "side": "side_2"
              }
            }
          ],
          "ball_movements": [
            {
              "to": {
                "x": 11,
                "y": 8,
                "side": "side_2"
              },
              "from": {
                "x": 14,
                "y": 4,
                "side": "side_2"
              },
              "ball_id": "B1"
            }
          ],
          "object_movements": [],
          "participant_movements": [
            {
              "to": {
                "x": 7,
                "y": 4,
                "side": "side_1"
              },
              "from": {
                "x": 10,
                "y": 3,
                "side": "side_1"
              },
              "participant_id": "P1"
            },
            {
              "to": {
                "x": 15,
                "y": 9,
                "side": "side_1"
              },
              "from": {
                "x": 13,
                "y": 9,
                "side": "side_1"
              },
              "participant_id": "P2"
            },
            {
              "to": {
                "x": 11,
                "y": 8,
                "side": "side_2"
              },
              "from": {
                "x": 8,
                "y": 6,
                "side": "side_2"
              },
              "participant_id": "P3"
            },
            {
              "to": {
                "x": 15,
                "y": 7,
                "side": "side_2"
              },
              "from": {
                "x": 14,
                "y": 4,
                "side": "side_2"
              },
              "participant_id": "P4"
            }
          ]
        },
        {
          "id": "S3",
          "balls": [
            {
              "id": "B1",
              "active": true,
              "location": {
                "x": 11,
                "y": 8,
                "side": "side_2"
              }
            }
          ],
          "actions": [],
          "objects": [],
          "annotations": [
            {
              "id": "text_1",
              "bold": false,
              "text": "Setter Sets, calls something and stay to defend the block or pulls back.",
              "type": "text",
              "align": "left",
              "width": 0.28,
              "border": false,
              "height": 0.28,
              "italic": false,
              "location": {
                "x": 8.3158,
                "y": 5.6405,
                "side": "side_2"
              },
              "font_size": 14,
              "background": false
            }
          ],
          "participants": [
            {
              "id": "P1",
              "active": true,
              "location": {
                "x": 7,
                "y": 4,
                "side": "side_1"
              }
            },
            {
              "id": "P2",
              "active": true,
              "location": {
                "x": 15,
                "y": 9,
                "side": "side_1"
              }
            },
            {
              "id": "P3",
              "active": true,
              "location": {
                "x": 11,
                "y": 8,
                "side": "side_2"
              }
            },
            {
              "id": "P4",
              "active": true,
              "location": {
                "x": 15,
                "y": 7,
                "side": "side_2"
              }
            }
          ],
          "ball_movements": [
            {
              "to": {
                "x": 15,
                "y": 8,
                "side": "side_2"
              },
              "from": {
                "x": 11,
                "y": 8,
                "side": "side_2"
              },
              "ball_id": "B1"
            }
          ],
          "object_movements": [],
          "participant_movements": [
            {
              "to": {
                "x": 7,
                "y": 5,
                "side": "side_2"
              },
              "from": {
                "x": 11,
                "y": 8,
                "side": "side_2"
              },
              "participant_id": "P3"
            },
            {
              "to": {
                "x": 15,
                "y": 8,
                "side": "side_2"
              },
              "from": {
                "x": 15,
                "y": 7,
                "side": "side_2"
              },
              "participant_id": "P4"
            }
          ]
        },
        {
          "id": "S4",
          "balls": [
            {
              "id": "B1",
              "active": true,
              "location": {
                "x": 15,
                "y": 8,
                "side": "side_2"
              }
            }
          ],
          "actions": [],
          "objects": [],
          "annotations": [
            {
              "id": "text_1",
              "bold": false,
              "text": "If spike is hard driven.  Stay on your position.",
              "type": "text",
              "align": "left",
              "width": 0.28,
              "border": false,
              "height": 0.16,
              "italic": false,
              "location": {
                "x": 4.5011,
                "y": 4.8842,
                "side": "side_1"
              },
              "font_size": 14,
              "background": false
            }
          ],
          "participants": [
            {
              "id": "P1",
              "active": true,
              "location": {
                "x": 7,
                "y": 4,
                "side": "side_1"
              }
            },
            {
              "id": "P2",
              "active": true,
              "location": {
                "x": 15,
                "y": 9,
                "side": "side_1"
              }
            },
            {
              "id": "P3",
              "active": true,
              "location": {
                "x": 7,
                "y": 5,
                "side": "side_2"
              }
            },
            {
              "id": "P4",
              "active": true,
              "location": {
                "x": 15,
                "y": 8,
                "side": "side_2"
              }
            }
          ],
          "ball_movements": [
            {
              "to": {
                "x": 7,
                "y": 4,
                "side": "side_1"
              },
              "from": {
                "x": 15,
                "y": 8,
                "side": "side_2"
              },
              "ball_id": "B1"
            }
          ],
          "object_movements": [],
          "participant_movements": [
            {
              "to": {
                "x": 12,
                "y": 7,
                "side": "side_1"
              },
              "from": {
                "x": 15,
                "y": 9,
                "side": "side_1"
              },
              "participant_id": "P2"
            },
            {
              "to": {
                "x": 15,
                "y": 4,
                "side": "side_2"
              },
              "from": {
                "x": 15,
                "y": 8,
                "side": "side_2"
              },
              "participant_id": "P4"
            }
          ]
        },
        {
          "id": "S5",
          "balls": [
            {
              "id": "B1",
              "active": true,
              "location": {
                "x": 7,
                "y": 4,
                "side": "side_1"
              }
            }
          ],
          "actions": [],
          "objects": [],
          "participants": [
            {
              "id": "P1",
              "active": true,
              "location": {
                "x": 7,
                "y": 4,
                "side": "side_1"
              }
            },
            {
              "id": "P2",
              "active": true,
              "location": {
                "x": 12,
                "y": 7,
                "side": "side_1"
              }
            },
            {
              "id": "P3",
              "active": true,
              "location": {
                "x": 7,
                "y": 5,
                "side": "side_2"
              }
            },
            {
              "id": "P4",
              "active": true,
              "location": {
                "x": 15,
                "y": 4,
                "side": "side_2"
              }
            }
          ],
          "ball_movements": [],
          "object_movements": [],
          "participant_movements": [
            {
              "to": {
                "x": 8,
                "y": 4,
                "side": "side_1"
              },
              "from": {
                "x": 7,
                "y": 4,
                "side": "side_1"
              },
              "participant_id": "P1"
            },
            {
              "to": {
                "x": 15,
                "y": 9,
                "side": "side_1"
              },
              "from": {
                "x": 12,
                "y": 7,
                "side": "side_1"
              },
              "participant_id": "P2"
            },
            {
              "to": {
                "x": 15,
                "y": 7,
                "side": "side_2"
              },
              "from": {
                "x": 15,
                "y": 4,
                "side": "side_2"
              },
              "participant_id": "P4"
            }
          ]
        },
        {
          "id": "S6",
          "balls": [
            {
              "id": "B1",
              "active": false,
              "location": {
                "x": 7,
                "y": 4,
                "side": "side_1"
              }
            },
            {
              "id": "B2",
              "active": true,
              "location": {
                "x": 15,
                "y": 7,
                "side": "side_2"
              }
            }
          ],
          "actions": [],
          "objects": [],
          "annotations": [
            {
              "id": "text_1",
              "bold": false,
              "text": "If high line, move to save",
              "type": "text",
              "align": "left",
              "width": 0.28,
              "border": false,
              "height": 0.16,
              "italic": false,
              "location": {
                "x": 5.7296,
                "y": 5.1421,
                "side": "side_1"
              },
              "font_size": 14,
              "background": false
            }
          ],
          "participants": [
            {
              "id": "P1",
              "active": true,
              "location": {
                "x": 8,
                "y": 4,
                "side": "side_1"
              }
            },
            {
              "id": "P2",
              "active": true,
              "location": {
                "x": 15,
                "y": 9,
                "side": "side_1"
              }
            },
            {
              "id": "P3",
              "active": true,
              "location": {
                "x": 7,
                "y": 5,
                "side": "side_2"
              }
            },
            {
              "id": "P4",
              "active": true,
              "location": {
                "x": 15,
                "y": 7,
                "side": "side_2"
              }
            }
          ],
          "ball_movements": [
            {
              "to": {
                "x": 16,
                "y": 3,
                "side": "side_1"
              },
              "from": {
                "x": 15,
                "y": 7,
                "side": "side_2"
              },
              "ball_id": "B2"
            }
          ],
          "object_movements": [],
          "participant_movements": [
            {
              "to": {
                "x": 16,
                "y": 3,
                "side": "side_1"
              },
              "from": {
                "x": 8,
                "y": 4,
                "side": "side_1"
              },
              "participant_id": "P1"
            },
            {
              "to": {
                "x": 11,
                "y": 7,
                "side": "side_1"
              },
              "from": {
                "x": 15,
                "y": 9,
                "side": "side_1"
              },
              "participant_id": "P2"
            },
            {
              "to": {
                "x": 15,
                "y": 5,
                "side": "side_2"
              },
              "from": {
                "x": 15,
                "y": 7,
                "side": "side_2"
              },
              "participant_id": "P4"
            }
          ]
        },
        {
          "id": "S7",
          "balls": [
            {
              "id": "B1",
              "active": true,
              "location": {
                "x": 16,
                "y": 3,
                "side": "side_1"
              }
            },
            {
              "id": "B2",
              "active": true,
              "location": {
                "x": 16,
                "y": 3,
                "side": "side_1"
              }
            }
          ],
          "actions": [],
          "objects": [],
          "participants": [
            {
              "id": "P1",
              "active": true,
              "location": {
                "x": 16,
                "y": 3,
                "side": "side_1"
              }
            },
            {
              "id": "P2",
              "active": true,
              "location": {
                "x": 11,
                "y": 7,
                "side": "side_1"
              }
            },
            {
              "id": "P3",
              "active": true,
              "location": {
                "x": 7,
                "y": 5,
                "side": "side_2"
              }
            },
            {
              "id": "P4",
              "active": true,
              "location": {
                "x": 15,
                "y": 5,
                "side": "side_2"
              }
            }
          ],
          "ball_movements": [],
          "object_movements": [],
          "participant_movements": []
        }
      ],
      "objects": [],
      "version": 1,
      "participants": [
        {
          "id": "P1",
          "role": "server/defender",
          "type": "player"
        },
        {
          "id": "P2",
          "role": "Blocker",
          "type": "player"
        },
        {
          "id": "P3",
          "role": "Passer 1",
          "type": "player"
        },
        {
          "id": "P4",
          "role": "Passer 2",
          "type": "player"
        }
      ]
    },
    "visibility": "shared",
    "status": "published",
    "published_at": "2026-11-01T10:31:59Z",
    "approved_at": nil,
    "skills": [
      {
        "title": "Hand Setting",
        "slug": "hand-setting"
      },
      {
        "title": "Signs",
        "slug": "signs"
      },
      {
        "title": "Always play close",
        "slug": "always-play-close-2"
      }
    ]
  },
  {
    "title": "Block Footwork Patterns",
    "setup_instructions": "Practice lateral movement along the net for blocking. Focus on shuffle steps and crossover techniques to position efficiently.",
    "ideal_num_players": 2,
    "difficulty_level": "beginner",
    "training_stage": "beginning",
    "min_players": 2,
    "max_players": 2,
    "slug": "block-footwork-patterns",
    "definition": {},
    "visibility": "shared",
    "status": "published",
    "published_at": "2026-11-01T10:31:59Z",
    "approved_at": nil,
    "skills": [
      {
        "title": "Hand Setting",
        "slug": "hand-setting"
      },
      {
        "title": "Foot work",
        "slug": "foot-work"
      },
      {
        "title": "Always play close",
        "slug": "always-play-close-2"
      }
    ]
  },
  {
    "title": "Peel and Defence Transition",
    "setup_instructions": "Blocker practices stepping away from net to defend various shot types. Quick transition from blocking to defensive stance for short and deep balls.",
    "ideal_num_players": 3,
    "difficulty_level": "intermediate",
    "training_stage": "beginning",
    "min_players": 2,
    "max_players": 4,
    "slug": "peel-and-defence-transition",
    "definition": {},
    "visibility": "shared",
    "status": "published",
    "published_at": "2026-11-01T10:31:59Z",
    "approved_at": nil,
    "skills": [
      {
        "title": "Hand Setting",
        "slug": "hand-setting"
      },
      {
        "title": "Peel - Hard driven",
        "slug": "peel-hard-driven"
      },
      {
        "title": "Peel - Short",
        "slug": "peel-short"
      },
      {
        "title": "Peel - Long",
        "slug": "peel-long"
      },
      {
        "title": "Always play close",
        "slug": "always-play-close-2"
      }
    ]
  },
  {
    "title": "Line Block Positioning",
    "setup_instructions": "Practice setting the block to cover the line shot. Outside hand aligns with sideline to seal off the angle and force cross-court.",
    "ideal_num_players": 3,
    "difficulty_level": "intermediate",
    "training_stage": "beginning",
    "min_players": 2,
    "max_players": 4,
    "slug": "line-block-positioning",
    "definition": {},
    "visibility": "shared",
    "status": "published",
    "published_at": "2026-11-01T10:31:59Z",
    "approved_at": nil,
    "skills": [
      {
        "title": "Hand Setting",
        "slug": "hand-setting"
      },
      {
        "title": "Block line",
        "slug": "block-line"
      },
      {
        "title": "Always play close",
        "slug": "always-play-close-2"
      }
    ]
  },
  {
    "title": "Cross Court Block Setup",
    "setup_instructions": "Position the block to cover cross-court shots. Inside hand covers middle, outside hand seals the cross-court angle to force line shots.",
    "ideal_num_players": 3,
    "difficulty_level": "intermediate",
    "training_stage": "beginning",
    "min_players": 2,
    "max_players": 4,
    "slug": "cross-court-block-setup",
    "definition": {},
    "visibility": "shared",
    "status": "published",
    "published_at": "2026-11-01T10:31:59Z",
    "approved_at": nil,
    "skills": [
      {
        "title": "Hand Setting",
        "slug": "hand-setting"
      },
      {
        "title": "Block cross",
        "slug": "block-cross"
      },
      {
        "title": "Always play close",
        "slug": "always-play-close-2"
      }
    ]
  },
  {
    "title": "Serve and Block Transition",
    "setup_instructions": "Server immediately transitions to blocking position after serving. Practice quick movement up to net to establish block against the return.",
    "ideal_num_players": 2,
    "difficulty_level": "intermediate",
    "training_stage": "beginning",
    "min_players": 2,
    "max_players": 2,
    "slug": "serve-and-block-transition",
    "definition": {},
    "visibility": "shared",
    "status": "published",
    "published_at": "2026-11-01T10:31:59Z",
    "approved_at": nil,
    "skills": [
      {
        "title": "Hand Setting",
        "slug": "hand-setting"
      },
      {
        "title": "Serve and go to block",
        "slug": "serve-and-go-to-block"
      },
      {
        "title": "Always play close",
        "slug": "always-play-close-2"
      }
    ]
  },
  {
    "title": "Block Landing and Turn",
    "setup_instructions": "Practice proper landing technique after blocking and quick body rotation. Transition from blocking stance to defensive or attacking readiness.",
    "ideal_num_players": 2,
    "difficulty_level": "beginner",
    "training_stage": "beginning",
    "min_players": 2,
    "max_players": 2,
    "slug": "block-landing-and-turn",
    "definition": {
      "side": {
        "grid": {
          "rows": 4,
          "columns": 5
        }
      },
      "balls": [],
      "steps": [
        {
          "id": "S1",
          "balls": [],
          "actions": [],
          "objects": [],
          "participants": [],
          "ball_movements": [],
          "object_movements": [],
          "participant_movements": []
        }
      ],
      "objects": [],
      "version": 1,
      "participants": []
    },
    "visibility": "shared",
    "status": "published",
    "published_at": "2026-11-01T10:31:59Z",
    "approved_at": nil,
    "skills": [
      {
        "title": "Hand Setting",
        "slug": "hand-setting"
      },
      {
        "title": "How to turn after block",
        "slug": "how-to-turn-after-block"
      },
      {
        "title": "Always play close",
        "slug": "always-play-close-2"
      }
    ]
  },
  {
    "title": "Target Serving",
    "setup_instructions": "Place targets in various court locations. Server practices hitting specific zones with consistency. Track success rate for each target area.",
    "ideal_num_players": 1,
    "difficulty_level": "beginner",
    "training_stage": "beginning",
    "min_players": 1,
    "max_players": 1,
    "slug": "target-serving",
    "definition": {},
    "visibility": "shared",
    "status": "published",
    "published_at": "2026-11-01T10:31:59Z",
    "approved_at": nil,
    "skills": [
      {
        "title": "Short",
        "slug": "short"
      },
      {
        "title": "Long",
        "slug": "long"
      },
      {
        "title": "Direction",
        "slug": "direction"
      }
    ]
  },
  {
    "title": "Jump Float Serve Practice",
    "setup_instructions": "Practice jump float serve technique focusing on minimal spin and unpredictable ball movement. Aim for consistent contact point and float action.",
    "ideal_num_players": 1,
    "difficulty_level": "intermediate",
    "training_stage": "beginning",
    "min_players": 1,
    "max_players": 1,
    "slug": "jump-float-serve-practice",
    "definition": {},
    "visibility": "shared",
    "status": "published",
    "published_at": "2026-11-01T10:31:59Z",
    "approved_at": nil,
    "skills": [
      {
        "title": "Arm swing",
        "slug": "arm-swing"
      },
      {
        "title": "Jump float",
        "slug": "jump-float"
      }
    ]
  },
  {
    "title": "Jump Serve Power",
    "setup_instructions": "Execute aggressive jump serves with topskin for power and downward trajectory. Focus on approach timing, contact point, and follow through.",
    "ideal_num_players": 1,
    "difficulty_level": "advanced",
    "training_stage": "beginning",
    "min_players": 1,
    "max_players": 1,
    "slug": "jump-serve-power",
    "definition": {},
    "visibility": "shared",
    "status": "published",
    "published_at": "2026-11-01T10:31:59Z",
    "approved_at": nil,
    "skills": [
      {
        "title": "Arm swing",
        "slug": "arm-swing"
      },
      {
        "title": "Jump serve",
        "slug": "jump-serve"
      }
    ]
  },
  {
    "title": "Environmental Serving",
    "setup_instructions": "Practice serving with attention to wind and sun conditions. Adjust position and technique based on environmental factors for optimal results.",
    "ideal_num_players": 1,
    "difficulty_level": "intermediate",
    "training_stage": "beginning",
    "min_players": 1,
    "max_players": 1,
    "slug": "environmental-serving",
    "definition": {},
    "visibility": "shared",
    "status": "published",
    "published_at": "2026-11-01T10:31:59Z",
    "approved_at": nil,
    "skills": [
      {
        "title": "Position of serve wind/sun",
        "slug": "position-of-serve-wind-sun"
      }
    ]
  },
  {
    "title": "Test New Drill",
    "setup_instructions": nil,
    "ideal_num_players": nil,
    "difficulty_level": nil,
    "training_stage": nil,
    "min_players": nil,
    "max_players": nil,
    "slug": "test-new-drill",
    "definition": {
      "side": {
        "grid": {
          "rows": 20,
          "columns": 10
        }
      },
      "view": {
        "orientation": "top_down"
      },
      "balls": [
        {
          "id": "b1",
          "type": "volleyball"
        }
      ],
      "steps": [
        {
          "id": "step_1",
          "balls": [
            {
              "id": "b1",
              "active": true,
              "location": {
                "x": 5,
                "y": 1,
                "side": "side_1"
              }
            }
          ],
          "actions": [
            {
              "action": {
                "type": "serve",
                "description": "Serve short over receiver P2"
              },
              "participant_id": "p1"
            },
            {
              "action": {
                "type": "approach",
                "description": "Move early forward."
              },
              "participant_id": "p3"
            }
          ],
          "objects": [],
          "annotations": [
            {
              "id": "text_1",
              "bold": false,
              "text": "Attack here",
              "type": "text",
              "align": "left",
              "width": 0.28,
              "border": false,
              "height": 0.16,
              "italic": false,
              "location": {
                "x": 7.499056425995884,
                "y": 1.746636954842029,
                "side": "side_1"
              },
              "font_size": 14,
              "background": false
            },
            {
              "id": "text_2",
              "bold": false,
              "text": "Attack here",
              "type": "text",
              "align": "left",
              "width": 0.28,
              "border": false,
              "height": 0.16,
              "italic": false,
              "location": {
                "x": 7.305298420329673,
                "y": 5.934353394001839,
                "side": "side_2"
              },
              "font_size": 14,
              "background": false
            }
          ],
          "description": "Server starts behind the baseline and serves toward the receiving team.",
          "participants": [
            {
              "id": "p1",
              "active": true,
              "location": {
                "x": 7,
                "y": 3,
                "side": "side_1"
              }
            },
            {
              "id": "p2",
              "active": true,
              "location": {
                "x": 3,
                "y": 6,
                "side": "side_2"
              }
            },
            {
              "id": "p3",
              "active": true,
              "location": {
                "x": 8,
                "y": 3,
                "side": "side_2"
              }
            },
            {
              "id": "p4",
              "active": false,
              "location": {
                "x": 5,
                "y": 18,
                "side": "side_2"
              }
            }
          ],
          "ball_movements": [
            {
              "to": {
                "x": 3,
                "y": 10,
                "side": "side_2"
              },
              "from": {
                "x": 5,
                "y": 1,
                "side": "side_1"
              },
              "ball_id": "b1",
              "description": "Ball travels from server toward receiver."
            }
          ],
          "object_movements": [],
          "participant_movements": [
            {
              "to": {
                "x": 3,
                "y": 9,
                "side": "side_2"
              },
              "from": {
                "x": 3,
                "y": 6,
                "side": "side_2"
              },
              "participant_id": "p2"
            },
            {
              "to": {
                "x": 5,
                "y": 15,
                "side": "side_2"
              },
              "from": {
                "x": 8,
                "y": 3,
                "side": "side_2"
              },
              "participant_id": "p3"
            }
          ]
        },
        {
          "id": "step_2",
          "balls": [
            {
              "id": "b1",
              "active": true,
              "location": {
                "x": 3,
                "y": 10,
                "side": "side_2"
              }
            }
          ],
          "actions": [
            {
              "action": {
                "type": "receive",
                "description": "Receive with controlled platform toward setter."
              },
              "participant_id": "p2"
            },
            {
              "action": {
                "type": "set",
                "description": "Move toward the ball and prepare to set."
              },
              "participant_id": "p3"
            }
          ],
          "objects": [],
          "description": "Receiver moves into position and passes toward the setter.",
          "participants": [
            {
              "id": "p1",
              "active": false,
              "location": {
                "x": 5,
                "y": 1,
                "side": "side_1"
              }
            },
            {
              "id": "p2",
              "active": true,
              "location": {
                "x": 3,
                "y": 9,
                "side": "side_2"
              }
            },
            {
              "id": "p3",
              "active": true,
              "location": {
                "x": 5,
                "y": 15,
                "side": "side_2"
              }
            }
          ],
          "ball_movements": [
            {
              "to": {
                "x": 4,
                "y": 17,
                "side": "side_2"
              },
              "from": {
                "x": 3,
                "y": 10,
                "side": "side_2"
              },
              "ball_id": "b1"
            }
          ],
          "object_movements": [],
          "participant_movements": [
            {
              "to": {
                "x": 6,
                "y": 12,
                "side": "side_2"
              },
              "from": {
                "x": 3,
                "y": 9,
                "side": "side_2"
              },
              "participant_id": "p2"
            },
            {
              "to": {
                "x": 4,
                "y": 17,
                "side": "side_2"
              },
              "from": {
                "x": 5,
                "y": 15,
                "side": "side_2"
              },
              "participant_id": "p3"
            }
          ]
        },
        {
          "id": "S1",
          "balls": [
            {
              "id": "b1",
              "active": true,
              "location": {
                "x": 4,
                "y": 17,
                "side": "side_2"
              }
            }
          ],
          "actions": [],
          "objects": [],
          "participants": [
            {
              "id": "p2",
              "active": true,
              "location": {
                "x": 6,
                "y": 12,
                "side": "side_2"
              }
            },
            {
              "id": "p3",
              "active": true,
              "location": {
                "x": 4,
                "y": 17,
                "side": "side_2"
              }
            }
          ],
          "ball_movements": [
            {
              "to": {
                "x": 6,
                "y": 17,
                "side": "side_2"
              },
              "from": {
                "x": 4,
                "y": 17,
                "side": "side_2"
              },
              "ball_id": "b1"
            }
          ],
          "object_movements": [],
          "participant_movements": [
            {
              "to": {
                "x": 6,
                "y": 16,
                "side": "side_2"
              },
              "from": {
                "x": 6,
                "y": 12,
                "side": "side_2"
              },
              "participant_id": "p2"
            },
            {
              "to": {
                "x": 3,
                "y": 8,
                "side": "side_2"
              },
              "from": {
                "x": 4,
                "y": 17,
                "side": "side_2"
              },
              "participant_id": "p3"
            }
          ]
        },
        {
          "id": "S2",
          "balls": [
            {
              "id": "b1",
              "active": true,
              "location": {
                "x": 6,
                "y": 17,
                "side": "side_2"
              }
            }
          ],
          "actions": [],
          "objects": [],
          "participants": [
            {
              "id": "p2",
              "active": true,
              "location": {
                "x": 6,
                "y": 16,
                "side": "side_2"
              }
            },
            {
              "id": "p3",
              "active": true,
              "location": {
                "x": 3,
                "y": 8,
                "side": "side_2"
              }
            }
          ],
          "ball_movements": [
            {
              "to": {
                "x": 8,
                "y": 3,
                "side": "side_1"
              },
              "from": {
                "x": 6,
                "y": 17,
                "side": "side_2"
              },
              "ball_id": "b1"
            }
          ],
          "object_movements": [],
          "participant_movements": []
        },
        {
          "id": "S3",
          "balls": [
            {
              "id": "b1",
              "active": true,
              "location": {
                "x": 8,
                "y": 3,
                "side": "side_1"
              }
            }
          ],
          "actions": [],
          "objects": [],
          "participants": [],
          "ball_movements": [],
          "object_movements": [],
          "participant_movements": []
        }
      ],
      "objects": [],
      "version": 1,
      "description": "Serve-and-attack drill: P1 tosses over the net, P2 passes, P3 sets, P2 hits hard-driven line. P1 crosses to block or peel.",
      "participants": [
        {
          "id": "p1",
          "role": "server",
          "type": "player"
        },
        {
          "id": "p2",
          "role": "receiver",
          "type": "player"
        },
        {
          "id": "p3",
          "role": "setter",
          "type": "player"
        },
        {
          "id": "p4",
          "role": "defender",
          "type": "player"
        },
        {
          "id": "p5",
          "role": "attacker",
          "type": "player"
        }
      ]
    },
    "visibility": "shared",
    "status": "published",
    "published_at": "2026-11-01T10:31:59Z",
    "approved_at": nil,
    "skills": [
      {
        "title": "Back set",
        "slug": "back-set"
      },
      {
        "title": "Nike position",
        "slug": "nike-position"
      },
      {
        "title": "Steps to hit",
        "slug": "steps-to-hit"
      }
    ]
  },
  {
    "title": "Block Landing and Turn",
    "setup_instructions": nil,
    "ideal_num_players": nil,
    "difficulty_level": "beginner",
    "training_stage": "warmup",
    "min_players": nil,
    "max_players": nil,
    "slug": "block-landing-and-turn-2",
    "definition": {},
    "visibility": "shared",
    "status": "published",
    "published_at": "2026-11-01T10:31:59Z",
    "approved_at": nil,
    "skills": [
      {
        "title": "Nike position",
        "slug": "nike-position"
      }
    ]
  }
].freeze

DISCIPLINE_NAMES.each { |name| Discipline.find_or_create_by!(name: name) }

SKILLS_DATA.each do |data|
  discipline = Discipline.find_by!(name: data[:discipline])
  skill = Skill.find_or_initialize_by(slug: data[:slug])
  skill.assign_attributes(discipline: discipline, title: data[:title], description: data[:description], visibility: data[:visibility], status: data[:status], published_at: data[:published_at] && Time.iso8601(data[:published_at]))
  skill.save!
end

DRILLS_DATA.each do |data|
  drill = Drill.find_or_initialize_by(slug: data[:slug])
  drill.assign_attributes(title: data[:title], setup_instructions: data[:setup_instructions], ideal_num_players: data[:ideal_num_players], difficulty_level: data[:difficulty_level], training_stage: data[:training_stage], min_players: data[:min_players], max_players: data[:max_players], slug: data[:slug], definition: data[:definition] || {}, visibility: data[:visibility], status: data[:status], published_at: data[:published_at] && Time.iso8601(data[:published_at]), approved_at: data[:approved_at] && Time.iso8601(data[:approved_at]))
  drill.save!
  drill.drill_skills.delete_all
  data.fetch(:skills, []).each do |skill_data|
    skill = Skill.find_by!(slug: skill_data[:slug])
    drill.drill_skills.create!(skill: skill)
  end
end

puts "Seeded 8 disciplines, 79 skills, 40 drills, and 95 drill-skill relationships."
