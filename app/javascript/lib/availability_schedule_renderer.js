function escapeHtml(text) {
  return String(text)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
}

function slotButtonClasses(available, interactive) {
  if (available && interactive) {
    return "w-full cursor-pointer rounded px-1 py-0.5 text-center text-[10px] transition bg-green-100 text-green-800 hover:bg-green-200 hover:ring-2 hover:ring-green-400 focus:outline-none focus:ring-2 focus:ring-green-500"
  }
  if (available) {
    return "block w-full cursor-pointer rounded px-1 py-0.5 text-center text-[10px] transition bg-green-100 text-green-800 hover:bg-green-200 hover:ring-2 hover:ring-green-400 focus:outline-none focus:ring-2 focus:ring-green-500"
  }
  if (interactive) {
    return "rounded px-1 py-0.5 text-center text-[10px] bg-gray-100 text-gray-400 line-through"
  }
  return available
    ? "rounded px-1 py-0.5 text-center text-[10px] bg-green-100 text-green-800"
    : "rounded px-1 py-0.5 text-center text-[10px] bg-gray-100 text-gray-400 line-through"
}

function bloqueButtonClasses(available, interactive) {
  if (available && interactive) {
    return "w-full cursor-pointer rounded px-1 py-1 text-center text-[10px] transition bg-green-100 text-green-800 hover:bg-green-200 hover:ring-2 hover:ring-green-400 focus:outline-none focus:ring-2 focus:ring-green-500"
  }
  if (available) {
    return "block w-full cursor-pointer rounded px-1 py-1 text-center text-[10px] transition bg-green-100 text-green-800 hover:bg-green-200 hover:ring-2 hover:ring-green-400 focus:outline-none focus:ring-2 focus:ring-green-500"
  }
  if (available === false) {
    return "rounded px-1 py-1 text-center text-[10px] bg-gray-100 text-gray-400 line-through"
  }
  return "rounded px-1 py-1 text-center text-[10px] bg-green-100 text-green-800"
}

function navLink(availabilityUrl, weekStart, label) {
  const href = `${availabilityUrl}?week_start=${encodeURIComponent(weekStart)}`
  return `<a href="${escapeHtml(href)}" class="text-sm font-medium text-rose-600 hover:underline" data-week-start="${escapeHtml(weekStart)}" data-action="click-&gt;availability-schedule#navigate">${escapeHtml(label)}</a>`
}

function renderNavigation(week, availabilityUrl) {
  const prev = week.showPrevWeek
    ? navLink(availabilityUrl, week.prevWeekStart, "← Semana anterior")
    : `<span class="text-sm text-gray-300">← Semana anterior</span>`

  const next = navLink(availabilityUrl, week.nextWeekStart, "Semana siguiente →")

  return `<div class="flex items-center justify-between">${prev}<span class="text-sm text-gray-600">${escapeHtml(week.rangeLabel)}</span>${next}</div>`
}

function renderHoraDay(day, interactive, loginPrompt) {
  const cells = day.hora.length
    ? day.hora.map((slot) => renderHoraSlot(day, slot, interactive, loginPrompt)).join("")
    : `<p class="text-center text-[10px] text-gray-300">—</p>`

  return `<div class="rounded-xl border border-gray-200 p-2"><p class="text-center text-xs font-semibold text-gray-700">${escapeHtml(day.dayShort)}</p><p class="text-center text-[10px] text-gray-400">${escapeHtml(day.dateLabel)}</p><div class="mt-2 space-y-1">${cells}</div></div>`
}

function renderHoraSlot(day, slot, interactive, loginPrompt) {
  const label = `${slot.start}–${slot.end}`
  if (interactive && slot.available) {
    return `<button type="button" data-action="click-&gt;booking-form#selectSlot" data-date="${escapeHtml(day.date)}" data-start-time="${escapeHtml(slot.start)}" class="${slotButtonClasses(true, true)}">${escapeHtml(label)}</button>`
  }
  if (loginPrompt && slot.checkoutUrl && slot.available) {
    return `<a href="${escapeHtml(slot.checkoutUrl)}" class="${slotButtonClasses(true, false)}" data-turbo-frame="_top">${escapeHtml(label)}</a>`
  }
  return `<div class="${slotButtonClasses(slot.available, interactive)}">${escapeHtml(label)}</div>`
}

function renderBloqueDay(day, interactive, loginPrompt) {
  const cells = day.bloque.length
    ? day.bloque.map((entry) => renderBloqueEntry(day, entry, interactive, loginPrompt)).join("")
    : `<p class="text-center text-[10px] text-gray-300">—</p>`

  return `<div class="rounded-xl border border-gray-200 p-2"><p class="text-center text-xs font-semibold text-gray-700">${escapeHtml(day.dayShort)}</p><p class="text-center text-[10px] text-gray-400">${escapeHtml(day.dateLabel)}</p><div class="mt-2 space-y-1">${cells}</div></div>`
}

function renderBloqueEntry(day, entry, interactive, loginPrompt) {
  const timeRange = `${entry.start}–${entry.end}`
  const inner = `<span class="block font-medium">${escapeHtml(entry.name)}</span><span class="block text-[9px] opacity-80">${escapeHtml(timeRange)}</span>`

  if (interactive && entry.available) {
    return `<button type="button" data-action="click-&gt;booking-form#selectBloque" data-date="${escapeHtml(day.date)}" data-slot-rate-id="${escapeHtml(entry.rateId)}" class="${bloqueButtonClasses(true, true)}">${inner}</button>`
  }
  if (loginPrompt && entry.checkoutUrl && entry.available) {
    return `<a href="${escapeHtml(entry.checkoutUrl)}" class="${bloqueButtonClasses(true, false)}" data-turbo-frame="_top">${inner}</a>`
  }
  if (entry.available) {
    return `<div class="${bloqueButtonClasses(true, false)}">${inner}</div>`
  }
  return `<div class="${bloqueButtonClasses(false, false)}"><span class="block font-medium">${escapeHtml(entry.name)}</span><span class="block text-[9px]">${escapeHtml(timeRange)}</span></div>`
}

function renderJornadaDay(day, interactive, loginPrompt) {
  const entry = day.jornada
  if (!entry) {
    return `<div class="rounded-xl border border-gray-200 p-2"><p class="text-center text-xs font-semibold text-gray-700">${escapeHtml(day.dayShort)}</p><p class="text-center text-[10px] text-gray-400">${escapeHtml(day.dateLabel)}</p><div class="mt-2"><p class="text-center text-[10px] text-gray-300">—</p></div></div>`
  }

  const timeRange = `${entry.start}–${entry.end}`
  const inner = `<span class="block font-medium">Día completo</span><span class="block text-[9px] opacity-80">${escapeHtml(timeRange)}</span>`
  let cell

  if (interactive && entry.available) {
    cell = `<button type="button" data-action="click-&gt;booking-form#selectJornada" data-date="${escapeHtml(day.date)}" class="${bloqueButtonClasses(true, true)}">${inner}</button>`
  } else if (loginPrompt && entry.checkoutUrl && entry.available) {
    cell = `<a href="${escapeHtml(entry.checkoutUrl)}" class="${bloqueButtonClasses(true, false)}" data-turbo-frame="_top">${inner}</a>`
  } else if (entry.available) {
    cell = `<div class="${bloqueButtonClasses(true, false)}">${inner}</div>`
  } else {
    cell = `<div class="${bloqueButtonClasses(false, false)}"><span class="block font-medium">Día completo</span><span class="block text-[9px]">${escapeHtml(timeRange)}</span></div>`
  }

  return `<div class="rounded-xl border border-gray-200 p-2"><p class="text-center text-xs font-semibold text-gray-700">${escapeHtml(day.dayShort)}</p><p class="text-center text-[10px] text-gray-400">${escapeHtml(day.dateLabel)}</p><div class="mt-2">${cell}</div></div>`
}

function renderWeekGrid(days, view, interactive, loginPrompt) {
  const dayHtml = days
    .map((day) => {
      if (view === "bloque") return renderBloqueDay(day, interactive, loginPrompt)
      if (view === "jornada") return renderJornadaDay(day, interactive, loginPrompt)
      return renderHoraDay(day, interactive, loginPrompt)
    })
    .join("")

  return `<div class="mt-4 overflow-x-auto"><div class="grid min-w-[640px] grid-cols-7 gap-2">${dayHtml}</div></div>`
}

function renderEmptyWeekNotice(week, availabilityUrl) {
  if (!week.emptyWeek) return ""

  const href = `${availabilityUrl}?week_start=${encodeURIComponent(week.nextWeekStart)}`
  return `<p class="mt-4 rounded-xl border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-950">No hay horarios visibles en esta semana (días pasados, fin de plantilla o sin agenda). <a href="${escapeHtml(href)}" class="font-medium text-rose-700 hover:underline" data-week-start="${escapeHtml(week.nextWeekStart)}" data-action="click-&gt;availability-schedule#navigate">Ver semana siguiente →</a></p>`
}

export function renderAvailabilityWeek(week, view, { interactive, loginPrompt, availabilityUrl }) {
  const navigation = renderNavigation(week, availabilityUrl)
  const grid = renderWeekGrid(week.days, view, interactive, loginPrompt)
  const emptyNotice = view === "hora" ? renderEmptyWeekNotice(week, availabilityUrl) : ""
  return `${navigation}${grid}${emptyNotice}`
}
