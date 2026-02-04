import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "board",
    "moveList",
    "status",
    "result",
    "spectator",
    "playButton",
    "coordsTop",
    "coordsLeft",
    "coordsRight",
    "coordsBottom",
    "speedRange",
    "movePageLabel",
    "termination",
    "resignedRow",
    "resignedBy",
    "forfeitRow",
    "forfeitBy",
    "drawRow",
    "drawReason"
  ]
  static values = {
    id: String,
    game: String,
    initialState: String,
    currentState: String,
    moves: Array,
    agentA: String,
    agentB: String,
    termination: String,
    resignedBy: String,
    forfeitBy: String,
    drawReason: String
  }

  connect() {
    this.pieceMap = {
      p: "♟",
      r: "♜",
      n: "♞",
      b: "♝",
      q: "♛",
      k: "♚",
      P: "♙",
      R: "♖",
      N: "♘",
      B: "♗",
      Q: "♕",
      K: "♔"
    }

    this.initialState = this.initialStateValue || this.boardFallbackState()
    this.currentState = this.currentStateValue || ""
    this.moves = this.parseMoves(this.movesValue)
    this.currentIndex = this.moves.length
    this.playTimer = null
    this.subscription = null
    this.pollTimer = null
    this.coordSize = null
    this.playInterval = 700
    this.pageSize = 20
    this.currentPage = 1
    if (this.hasSpeedRangeTarget) {
      this.playInterval = parseInt(this.speedRangeTarget.value, 10) || 700
    }

    if (this.hasBoardTarget) this.setIndex(this.currentIndex)
    this.updateOutcomeDetails({
      termination: this.terminationValue,
      resigned_by_side: this.resignedByValue,
      forfeit_by_side: this.forfeitByValue,
      draw_reason: this.drawReasonValue
    })
    this.subscribe()
  }

  disconnect() {
    this.stop()
    if (this.subscription) this.subscription.unsubscribe()
    if (this.pollTimer) clearInterval(this.pollTimer)
  }

  start() {
    this.stop()
    this.setIndex(0)
  }

  prev() {
    this.stop()
    this.setIndex(this.currentIndex - 1)
  }

  next() {
    this.stop()
    this.setIndex(this.currentIndex + 1)
  }

  end() {
    this.stop()
    this.setIndex(this.moves.length)
  }

  togglePlay() {
    if (this.playTimer) {
      this.stop()
      return
    }
    if (this.currentIndex >= this.moves.length) {
      this.setIndex(0)
    }
    this.setPlayLabel("Pause")
    this.playTimer = setInterval(() => {
      if (this.currentIndex >= this.moves.length) {
        this.stop()
        return
      }
      this.setIndex(this.currentIndex + 1)
    }, this.playInterval)
  }

  stop() {
    if (!this.playTimer) return
    clearInterval(this.playTimer)
    this.playTimer = null
    this.setPlayLabel("Play")
  }

  updateSpeed() {
    if (!this.hasSpeedRangeTarget) return
    this.playInterval = parseInt(this.speedRangeTarget.value, 10) || 700
    if (this.playTimer) {
      this.stop()
      this.togglePlay()
    }
  }

  setIndex(index) {
    this.currentIndex = Math.max(0, Math.min(index, this.moves.length))
    const snapshot = this.snapshotForIndex(this.currentIndex)
    if (this.gameValue === "chess") {
      this.renderChessBoard(snapshot)
      this.renderCoords(8)
    } else if (this.gameValue === "go") {
      this.renderGoBoard(snapshot)
    }
    this.renderMoves()
  }

  snapshotForIndex(index) {
    if (this.moves.length === 0) {
      return this.currentState || this.initialState
    }
    if (index === 0) {
      return this.initialState
    }
    return this.moves[index - 1]?.state || this.currentState || this.initialState
  }

  renderChessBoard(fen) {
    if (!this.hasBoardTarget || !fen) return
    const rows = fen.split(" ")[0].split("/")
    this.boardTarget.innerHTML = ""
    rows.forEach((row, rowIndex) => {
      let colIndex = 0
      row.split("").forEach((char) => {
        const count = parseInt(char, 10)
        if (Number.isInteger(count)) {
          for (let i = 0; i < count; i += 1) {
            this.addChessSquare(rowIndex, colIndex, "")
            colIndex += 1
          }
        } else {
          this.addChessSquare(rowIndex, colIndex, this.pieceMap[char] || "")
          colIndex += 1
        }
      })
    })
  }

  addChessSquare(row, col, content) {
    const square = document.createElement("div")
    square.className = `chess-square ${(row + col) % 2 === 0 ? "light" : "dark"}`
    square.textContent = content
    this.boardTarget.appendChild(square)
  }

  renderGoBoard(stateJson) {
    if (!this.hasBoardTarget || !stateJson) return
    let data = null
    try {
      data = JSON.parse(stateJson)
    } catch (error) {
      return
    }
    const size = data.size || 19
    const board = data.board || ""
    this.boardTarget.style.setProperty("--size", size)
    this.boardTarget.innerHTML = ""
    this.renderCoords(size)
    for (let i = 0; i < size * size; i += 1) {
      const point = document.createElement("div")
      point.className = "go-point"
      const cell = board[i]
      if (cell === "b" || cell === "w") {
        const stone = document.createElement("div")
        stone.className = `go-stone ${cell === "b" ? "go-stone-black" : "go-stone-white"}`
        point.appendChild(stone)
      }
      this.boardTarget.appendChild(point)
    }
  }

  renderMoves() {
    if (!this.hasMoveListTarget) return
    this.moveListTarget.innerHTML = ""
    const totalMoves = Math.ceil(this.moves.length / 2)
    if (totalMoves === 0) {
      this.updatePageLabel(0, 0, 0)
      return
    }
    const totalPages = Math.max(1, Math.ceil(totalMoves / this.pageSize))
    this.currentPage = Math.min(Math.max(1, this.currentPage), totalPages)
    const startMove = (this.currentPage - 1) * this.pageSize + 1
    const endMove = Math.min(totalMoves, startMove + this.pageSize - 1)
    this.updatePageLabel(this.currentPage, totalPages, startMove, endMove, totalMoves)
    for (let moveNum = startMove; moveNum <= endMove; moveNum += 1) {
      const i = (moveNum - 1) * 2
      const row = document.createElement("li")
      row.className = "move-row"
      const first = this.moves[i]
      const second = this.moves[i + 1]

      const num = document.createElement("span")
      num.className = "move-num"
      num.textContent = `${moveNum}.`

      const left = document.createElement("span")
      left.className = "move-cell"
      left.textContent = first ? `${first.actor} ${first.notation} (${first.display})` : "-"
      if (first) {
        left.dataset.index = (i + 1).toString()
        left.dataset.action = "click->match-replay#jumpToMove"
      }
      if (i === this.currentIndex - 1) left.classList.add("move-active")

      const right = document.createElement("span")
      right.className = "move-cell"
      right.textContent = second ? `${second.actor} ${second.notation} (${second.display})` : "-"
      if (second) {
        right.dataset.index = (i + 2).toString()
        right.dataset.action = "click->match-replay#jumpToMove"
      }
      if (i + 1 === this.currentIndex - 1) right.classList.add("move-active")

      row.appendChild(num)
      row.appendChild(left)
      row.appendChild(right)
      this.moveListTarget.appendChild(row)
    }
  }

  jumpToMove(event) {
    const target = event.currentTarget
    const index = parseInt(target.dataset.index, 10)
    if (Number.isInteger(index)) {
      this.stop()
      this.setIndex(index)
    }
  }

  pageStart() {
    this.currentPage = 1
    this.renderMoves()
  }

  pageEnd() {
    const totalMoves = Math.ceil(this.moves.length / 2)
    const totalPages = Math.max(1, Math.ceil(totalMoves / this.pageSize))
    this.currentPage = totalPages
    this.renderMoves()
  }

  pagePrev() {
    this.currentPage = Math.max(1, this.currentPage - 1)
    this.renderMoves()
  }

  pageNext() {
    const totalMoves = Math.ceil(this.moves.length / 2)
    const totalPages = Math.max(1, Math.ceil(totalMoves / this.pageSize))
    this.currentPage = Math.min(totalPages, this.currentPage + 1)
    this.renderMoves()
  }

  updatePageLabel(currentPage, totalPages, startMove, endMove, totalMoves) {
    if (!this.hasMovePageLabelTarget) return
    if (totalMoves === 0) {
      this.movePageLabelTarget.textContent = "No moves yet"
      return
    }
    this.movePageLabelTarget.textContent = `Page ${currentPage} of ${totalPages} · Moves ${startMove}–${endMove} of ${totalMoves}`
  }

  renderCoords(size) {
    if (!this.hasCoordsTopTarget || !this.hasCoordsLeftTarget || !this.hasCoordsRightTarget || !this.hasCoordsBottomTarget) return
    if (this.coordSize === size) return
    this.coordSize = size

    const letters = this.gameValue === "go" ? this.goLetters(size) : this.chessLetters(size)
    const numbers = []
    for (let i = size; i >= 1; i -= 1) numbers.push(i.toString())

    this.coordsTopTarget.innerHTML = ""
    this.coordsBottomTarget.innerHTML = ""
    this.coordsLeftTarget.innerHTML = ""
    this.coordsRightTarget.innerHTML = ""

    letters.forEach((letter) => {
      const top = document.createElement("span")
      top.textContent = letter
      this.coordsTopTarget.appendChild(top)

      const bottom = document.createElement("span")
      bottom.textContent = letter
      this.coordsBottomTarget.appendChild(bottom)
    })

    numbers.forEach((num) => {
      const left = document.createElement("span")
      left.textContent = num
      this.coordsLeftTarget.appendChild(left)

      const right = document.createElement("span")
      right.textContent = num
      this.coordsRightTarget.appendChild(right)
    })
  }

  chessLetters(size) {
    return Array.from({ length: size }, (_, i) => String.fromCharCode(65 + i))
  }

  goLetters(size) {
    const letters = []
    let code = 65
    while (letters.length < size) {
      const letter = String.fromCharCode(code)
      if (letter !== "I") letters.push(letter)
      code += 1
    }
    return letters
  }

  updateFromPayload(data) {
    if (!data) return
    this.initialState = data.initial_state || this.initialState
    this.currentState = data.current_state || this.currentState
    this.moves = this.parseMoves(data.moves || this.moves)
    if (this.currentIndex > this.moves.length) this.currentIndex = this.moves.length
    this.setIndex(this.currentIndex)
    if (this.hasStatusTarget) this.statusTarget.textContent = this.humanize(data.status || "")
    if (this.hasResultTarget) this.resultTarget.textContent = data.result || "*"
    this.updateOutcomeDetails(data)
    if (this.hasSpectatorTarget && data.status !== "running") {
      this.spectatorTarget.textContent = "-"
    }
  }

  subscribe() {
    if (!this.idValue) return
    const cable = window.ActionCable ? window.ActionCable.createConsumer() : null
    if (cable) {
      this.subscription = cable.subscriptions.create(
        { channel: "MatchChannel", match_id: this.idValue },
        {
          received: (data) => {
            if (data && data.spectators !== undefined) {
              if (this.hasSpectatorTarget) this.spectatorTarget.textContent = data.spectators
              return
            }
            this.updateFromPayload(data)
          }
        }
      )
    } else {
      this.pollTimer = setInterval(() => this.fetchMatch(), 4000)
    }
  }

  fetchMatch() {
    fetch(`/matches/${this.idValue}.json`)
      .then((res) => res.json())
      .then((data) => this.updateFromPayload(data))
      .catch(() => {})
  }

  parseMoves(value) {
    if (!value) return []
    if (Array.isArray(value)) return value
    try {
      return JSON.parse(value)
    } catch (error) {
      return []
    }
  }

  boardFallbackState() {
    if (!this.hasBoardTarget) return ""
    return this.boardTarget.dataset.fen || this.boardTarget.dataset.state || ""
  }

  setPlayLabel(label) {
    if (!this.hasPlayButtonTarget) return
    this.playButtonTarget.textContent = label
  }

  humanize(value) {
    return value
      .replace(/_/g, " ")
      .replace(/\b\w/g, (c) => c.toUpperCase())
  }

  updateOutcomeDetails(data) {
    if (!data) return

    if (this.hasTerminationTarget) {
      this.terminationTarget.textContent = data.termination || "-"
    }

    this.applySideRow(
      this.hasResignedRowTarget ? this.resignedRowTarget : null,
      this.hasResignedByTarget ? this.resignedByTarget : null,
      data.resigned_by_side
    )

    this.applySideRow(
      this.hasForfeitRowTarget ? this.forfeitRowTarget : null,
      this.hasForfeitByTarget ? this.forfeitByTarget : null,
      data.forfeit_by_side
    )

    if (this.hasDrawRowTarget) {
      if (data.draw_reason) {
        this.drawRowTarget.hidden = false
        if (this.hasDrawReasonTarget) this.drawReasonTarget.textContent = data.draw_reason
      } else {
        this.drawRowTarget.hidden = true
      }
    }
  }

  applySideRow(rowTarget, textTarget, side) {
    if (!rowTarget) return
    if (!side) {
      rowTarget.hidden = true
      return
    }
    rowTarget.hidden = false
    if (textTarget) textTarget.textContent = this.sideLabel(side)
  }

  sideLabel(side) {
    if (side === "a") return this.agentAValue || "Opponent A"
    if (side === "b") return this.agentBValue || "Opponent B"
    return "-"
  }
}
