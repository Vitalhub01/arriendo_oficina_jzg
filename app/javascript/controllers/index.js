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
import LazyImageController from "controllers/lazy_image_controller"
import SortableListController from "controllers/sortable_list_controller"
import AvailabilityScheduleController from "controllers/availability_schedule_controller"
import CheckoutAuthController from "controllers/checkout_auth_controller"
import CheckoutFormController from "controllers/checkout_form_controller"
import PhotoLightboxController from "controllers/photo_lightbox_controller"

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
application.register("lazy-image", LazyImageController)
application.register("sortable-list", SortableListController)
application.register("availability-schedule", AvailabilityScheduleController)
application.register("checkout-auth", CheckoutAuthController)
application.register("checkout-form", CheckoutFormController)
application.register("photo-lightbox", PhotoLightboxController)
window.Stimulus = application

export { application }
