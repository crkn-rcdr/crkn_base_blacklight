import { Application } from "@hotwired/stimulus";

// Import all controllers
import CheckboxFacetController from "./checkbox_facet_controller";
import CopyLinkController from "./copy_link_controller";
import DownloadStatusController from "./download_status_controller";
import ResizableSidebarController from "./resizable_sidebar_controller";
import OpenseadragonPreviewController from "./openseadragon_preview_controller";
import FeedbackBannerController from "./feedback_banner_controller";
import SlideshowController from "./slideshow_controller";
import MembersFilterController from "./members_filter_controller";
import FacetAccordionController from "./facet_accordion_controller";

// Create Stimulus application
const application = Application.start();

// Register controllers
application.register("checkbox-facet", CheckboxFacetController);
application.register("copy-link", CopyLinkController);
application.register("download-status", DownloadStatusController);
application.register("resizable-sidebar", ResizableSidebarController);
application.register("openseadragon-preview", OpenseadragonPreviewController);
application.register("feedback-banner", FeedbackBannerController);
application.register("slideshow", SlideshowController);
application.register("members-filter", MembersFilterController);
application.register("facet-accordion", FacetAccordionController);

export { application };
