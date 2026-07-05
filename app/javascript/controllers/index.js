import { Application } from "@hotwired/stimulus"
import BookingFormController from "controllers/booking_form_controller"
import BookingTypeController from "controllers/booking_type_controller"
import GalleryController from "controllers/gallery_controller"
import MapController from "controllers/map_controller"
import MapIndexController from "controllers/map_index_controller"
import SearchSheetController from "controllers/search_sheet_controller"

const application = Application.start()
application.register("booking-form", BookingFormController)
application.register("booking-type", BookingTypeController)
application.register("gallery", GalleryController)
application.register("map", MapController)
application.register("map-index", MapIndexController)
application.register("search-sheet", SearchSheetController)
window.Stimulus = application

export { application }
