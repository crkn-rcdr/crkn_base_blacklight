import { Application } from "@hotwired/stimulus";

// Import all controllers
import CheckboxFacetController from "./checkbox_facet_controller";
import CopyLinkController from "./copy_link_controller";
import DownloadStatusController from "./download_status_controller";

// Create Stimulus application
const application = Application.start();

// Register controllers
application.register("checkbox-facet", CheckboxFacetController);
application.register("copy-link", CopyLinkController);
application.register("download-status", DownloadStatusController);

export { application };
