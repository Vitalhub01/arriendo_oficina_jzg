import { Application } from "@hotwired/stimulus"
import BookingFormController from "controllers/booking_form_controller"
import BookingTypeController from "controllers/booking_type_controller"
import GalleryController from "controllers/gallery_controller"
import MapController from "controllers/map_controller"
import MapIndexController from "controllers/map_index_controller"
import SearchSheetController from "controllers/search_sheet_controller"
import FlashController from "controllers/flash_controller"
import AdminScheduleController from "controllers/admin_schedule_controller"
import PhotoManagerController from "controllers/photo_manager_controller"
import GallerySetController from "controllers/gallery_set_controller"
import AutoSubmitController from "controllers/auto_submit_controller"
import PriceCycleController from "controllers/price_cycle_controller"

const application = Application.start()
application.register("booking-form", BookingFormController)
application.register("booking-type", BookingTypeController)
application.register("gallery", GalleryController)
application.register("map", MapController)
application.register("map-index", MapIndexController)
application.register("search-sheet", SearchSheetController)
application.register("flash", FlashController)
application.register("admin-schedule", AdminScheduleController)
application.register("photo-manager", PhotoManagerController)
application.register("gallery-set", GallerySetController)
application.register("auto-submit", AutoSubmitController)
application.register("price-cycle", PriceCycleController)
window.Stimulus = application

export { application }
