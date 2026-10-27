export const PERIOD_BLOCKED_MESSAGE =
  "Hay al menos una hora reservada o bloqueada en esa fecha; no se puede reservar el bloque o la jornada completa."

export function periodIssueMessage(issue) {
  if (issue === "reserved" || issue === "blocked") {
    return PERIOD_BLOCKED_MESSAGE
  }
  return "No hay horario disponible para esa fecha en la franja elegida."
}

export function formatCLP(cents) {
  return new Intl.NumberFormat("es-CL", {
    style: "currency",
    currency: "CLP",
    maximumFractionDigits: 0
  }).format(cents)
}

export function minutesBetween(start, end) {
  const [sh, sm] = start.split(":").map(Number)
  const [eh, em] = end.split(":").map(Number)
  return (eh * 60 + em) - (sh * 60 + sm)
}

export function parseDateTime(dateIso, time) {
  const [year, month, day] = dateIso.split("-").map(Number)
  const [hour, minute] = time.split(":").map(Number)
  return new Date(year, month - 1, day, hour, minute, 0, 0)
}

export function blocksForDate(blocksByDay, dateIso) {
  if (!dateIso) return []
  const date = new Date(dateIso + "T12:00:00")
  const day = (date.getDay() + 6) % 7
  return blocksByDay[String(day)] || []
}

export function isActiveOnDate(block, dateIso) {
  if (!block.effective_until) return true
  return dateIso <= block.effective_until
}

export function isBlockedOnDate(block, dateIso, overrides) {
  return overrides.some(
    (o) => o.schedule_block_id === block.id && o.date === dateIso && o.blocked
  )
}

export function isReservedBlock(block, dateIso, reservedIntervals) {
  const blockStart = parseDateTime(dateIso, block.start)
  const blockEnd = parseDateTime(dateIso, block.end)
  return (reservedIntervals || []).some((interval) => {
    const start = new Date(interval.start)
    const end = new Date(interval.end)
    return start < blockEnd && end > blockStart
  })
}

export function isPastBlock(block, dateIso, today, nowTime) {
  if (today && nowTime) {
    if (dateIso > today) return false
    if (dateIso < today) return true
    return block.start < nowTime
  }

  const [year, month, day] = dateIso.split("-").map(Number)
  const [hour, minute] = block.start.split(":").map(Number)
  const startAt = new Date(year, month - 1, day, hour, minute, 0, 0)
  return startAt <= new Date()
}

export function priceForBlock(block, dateIso, overrides) {
  const override = overrides.find(
    (o) => o.schedule_block_id === block.id && o.date === dateIso
  )
  if (override?.price) return override.price
  return block.price
}

export function blocksInWindow(blocksByDay, dateIso, windowStart, windowEnd) {
  const blocks = blocksForDate(blocksByDay, dateIso)
  return blocks
    .filter((block) => block.start >= windowStart && block.end <= windowEnd)
    .sort((a, b) => a.start.localeCompare(b.start))
}

export function periodWindowIssue(blocksByDay, overrides, reservedIntervals, dateIso, windowStart, windowEnd, today, nowTime) {
  const blocks = blocksInWindow(blocksByDay, dateIso, windowStart, windowEnd)
  if (blocks.length === 0) return "no_schedule"

  const contiguous = blocks.every((block, index) => {
    if (index === 0) return true
    return blocks[index - 1].end === block.start
  })
  if (!contiguous) return "no_schedule"

  for (const block of blocks) {
    if (!isActiveOnDate(block, dateIso)) return "unavailable"
    if (isBlockedOnDate(block, dateIso, overrides)) return "blocked"
    if (isPastBlock(block, dateIso, today, nowTime)) return "past"
    if (isReservedBlock(block, dateIso, reservedIntervals)) return "reserved"
  }

  return null
}

export function hourlySelectionValid(
  blocksByDay,
  overrides,
  reservedIntervals,
  dateIso,
  slotCount,
  startTime,
  minimumSlots,
  today,
  nowTime
) {
  if (!dateIso || !startTime) return false
  if (slotCount < minimumSlots) return false

  return (
    calculateHourlyTotal(
      blocksByDay,
      overrides,
      reservedIntervals,
      dateIso,
      slotCount,
      startTime,
      today,
      nowTime
    ) > 0
  )
}

export function hourlyEndTime(blocksByDay, dateIso, startTime, slotCount) {
  const blocks = blocksForDate(blocksByDay, dateIso)
  const startIndex = blocks.findIndex((b) => b.start === startTime)
  if (startIndex < 0) return startTime

  const lastBlock = blocks[startIndex + slotCount - 1]
  return lastBlock?.end || startTime
}

export function calculateHourlyTotal(blocksByDay, overrides, reservedIntervals, dateIso, slotCount, startTime, today, nowTime) {
  const blocks = blocksForDate(blocksByDay, dateIso)
  const startIndex = blocks.findIndex((b) => b.start === startTime)
  if (startIndex < 0) return 0

  let total = 0
  for (let i = 0; i < slotCount; i++) {
    const block = blocks[startIndex + i]
    if (!block) return 0
    if (!isActiveOnDate(block, dateIso)) return 0
    if (isBlockedOnDate(block, dateIso, overrides)) return 0
    if (isPastBlock(block, dateIso, today, nowTime)) return 0
    if (isReservedBlock(block, dateIso, reservedIntervals)) return 0
    if (i > 0 && blocks[startIndex + i - 1].end !== block.start) return 0
    total += priceForBlock(block, dateIso, overrides)
  }
  return total
}

export function selectableHourlyBlocks(blocksByDay, overrides, reservedIntervals, dateIso, today, nowTime) {
  const blocks = blocksForDate(blocksByDay, dateIso)
  return blocks.filter(
    (block) =>
      isActiveOnDate(block, dateIso) &&
      !isBlockedOnDate(block, dateIso, overrides) &&
      !isPastBlock(block, dateIso, today, nowTime) &&
      !isReservedBlock(block, dateIso, reservedIntervals)
  )
}
