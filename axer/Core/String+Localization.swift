import Foundation

// MARK: - Localization Helper

extension String {
    /// Returns a localized string from Localizable.strings
    var localized: String {
        NSLocalizedString(self, comment: "")
    }

    /// Returns a localized string with format arguments
    func localized(with arguments: CVarArg...) -> String {
        String(format: NSLocalizedString(self, comment: ""), arguments: arguments)
    }
}

// MARK: - Localization Keys

/// Centralized localization keys for type-safe access
enum L10n {
    // MARK: - Common
    enum Common {
        static let cancel = "common.cancel".localized
        static let save = "common.save".localized
        static let close = "common.close".localized
        static let delete = "common.delete".localized
        static let edit = "common.edit".localized
        static let add = "common.add".localized
        static let done = "common.done".localized
        static let next = "common.next".localized
        static let back = "common.back".localized
        static let `continue` = "common.continue".localized
        static let loading = "common.loading".localized
        static let error = "common.error".localized
        static let ok = "common.ok".localized
        static let yes = "common.yes".localized
        static let no = "common.no".localized
        static let search = "common.search".localized
        static let requiredField = "common.required_field".localized
    }

    // MARK: - Login
    enum Login {
        static let title = "login.title".localized
        static let subtitle = "login.subtitle".localized
        static let emailPlaceholder = "login.email_placeholder".localized
        static let passwordPlaceholder = "login.password_placeholder".localized
        static let button = "login.button".localized
        static let errorInvalidCredentials = "login.error_invalid_credentials".localized
    }

    // MARK: - Sign Up
    enum SignUp {
        static let title = "signup.title".localized
        static let subtitle = "signup.subtitle".localized
        static let fullnamePlaceholder = "signup.fullname_placeholder".localized
        static let emailPlaceholder = "signup.email_placeholder".localized
        static let passwordPlaceholder = "signup.password_placeholder".localized
        static let termsText = "signup.terms_text".localized
        static let passwordHint = "signup.password_hint".localized
        static let button = "signup.button".localized
    }

    // MARK: - Welcome
    enum Welcome {
        static let appName = "welcome.app_name".localized
        static let tagline = "welcome.tagline".localized
        static let createWorkshop = "welcome.create_workshop".localized
        static let haveInvite = "welcome.have_invite".localized
        static let haveAccount = "welcome.have_account".localized
    }

    // MARK: - Home
    enum Home {
        static func greeting(_ name: String) -> String {
            "home.greeting".localized(with: name)
        }
        static let newOrder = "home.new_order".localized
        static let activeOrders = "home.active_orders".localized
        static let readyDelivery = "home.ready_delivery".localized
        static let noneReady = "home.none_ready".localized
        static let approvedToday = "home.approved_today".localized
        static let quotesApproved = "home.quotes_approved".localized
        static func monthSummary(_ month: String) -> String {
            "home.month_summary".localized(with: month)
        }
        static let recentOrders = "home.recent_orders".localized
        static let viewAll = "home.view_all".localized
        static let noOrdersYet = "home.no_orders_yet".localized
        static let createFirst = "home.create_first".localized
    }

    // MARK: - Orders
    enum Orders {
        static let title = "orders.title".localized
        static let loading = "orders.loading".localized
        static let searchPlaceholder = "orders.search_placeholder".localized
        static let newOrder = "orders.new_order".localized
        static let scanQr = "orders.scan_qr".localized
        static let allStatuses = "orders.all_statuses".localized
        static let qrNotFound = "orders.qr_not_found".localized
        static let scanQrAccessibility = "orders.scan_qr_accessibility".localized
        static let scanQrHint = "orders.scan_qr_hint".localized
        static let all = "orders.all".localized
        static let myOrders = "orders.my_orders".localized
        static let noOrders = "orders.no_orders".localized
        static let noResults = "orders.no_results".localized
        static let createFirst = "orders.create_first".localized
        static let tryAnother = "orders.try_another".localized
        static let searchHint = "orders.search_hint".localized
        static let noMoreOrders = "orders.no_more_orders".localized
    }

    // MARK: - Order Detail
    enum OrderDetail {
        static let notFound = "order_detail.not_found".localized
        static let progress = "order_detail.progress".localized
        static let currentStatus = "order_detail.current_status".localized
        static let nextStatus = "order_detail.next_status".localized
        static let client = "order_detail.client".localized
        static let responsible = "order_detail.responsible".localized
        static let mine = "order_detail.mine".localized
        static let unassigned = "order_detail.unassigned".localized
        static let takeOrderHint = "order_detail.take_order_hint".localized
        static let takeOrder = "order_detail.take_order".localized
        static let assign = "order_detail.assign".localized
        static let takeOrderConfirm = "order_detail.take_order_confirm".localized
        static let device = "order_detail.device".localized
        static let initialDiagnosis = "order_detail.initial_diagnosis".localized
        static let reportedProblem = "order_detail.reported_problem".localized
        static let quote = "order_detail.quote".localized
        static func itemsCount(_ count: Int) -> String {
            "order_detail.items_count".localized(with: count)
        }
        static let createQuote = "order_detail.create_quote".localized
        static let note = "order_detail.note".localized
        static let noActivity = "order_detail.no_activity".localized
        static let changeStatus = "order_detail.change_status".localized
        static let printLabel = "order_detail.print_label".localized
        static let shareTracking = "order_detail.share_tracking".localized
        static let generateLink = "order_detail.generate_link".localized
        static let internalNotesHint = "order_detail.internal_notes_hint".localized
        static let current = "order_detail.current".localized
        static let preview = "order_detail.preview".localized
        static let newNote = "order_detail.new_note".localized
        static let assignTo = "order_detail.assign_to".localized
        static let shareOrder = "order_detail.share_order".localized
        static let whatsapp = "order_detail.whatsapp".localized
        static let email = "order_detail.email".localized
        static let take = "order_detail.take".localized
    }

    // MARK: - New Order
    enum NewOrder {
        static let title = "new_order.title".localized
        static let selectCustomer = "new_order.select_customer".localized
        static let customerNotFound = "new_order.customer_not_found".localized
        static let createCustomer = "new_order.create_customer".localized
        static let newCustomer = "new_order.new_customer".localized
        static let createCustomerButton = "new_order.create_customer_button".localized
        static let deviceData = "new_order.device_data".localized
        static let deviceType = "new_order.device_type".localized
        static let brand = "new_order.brand".localized
        static let model = "new_order.model".localized
        static let deviceStatus = "new_order.device_status".localized
        static let turnsOn = "new_order.turns_on".localized
        static let doesntTurnOn = "new_order.doesnt_turn_on".localized
        static let quickChecklist = "new_order.quick_checklist".localized
        static let additionalInfo = "new_order.additional_info".localized
        static let passwordPattern = "new_order.password_pattern".localized
        static let describeProblem = "new_order.describe_problem".localized
        static let problemPlaceholder = "new_order.problem_placeholder".localized
        static let photosOptional = "new_order.photos_optional".localized
        static let camera = "new_order.camera".localized
        static let gallery = "new_order.gallery".localized
        static let summary = "new_order.summary".localized
        static let selectBrand = "new_order.select_brand".localized
        static let selectModel = "new_order.select_model".localized
        static func addBrand(_ name: String) -> String {
            "new_order.add_brand".localized(with: name)
        }
        static let brandWillSave = "new_order.brand_will_save".localized
        static let noModelsSaved = "new_order.no_models_saved".localized
        static let typeToAdd = "new_order.type_to_add".localized
        static func modelWillSave(_ brand: String) -> String {
            "new_order.model_will_save".localized(with: brand)
        }
        static let fullnamePlaceholder = "new_order.fullname_placeholder".localized
        static let phonePlaceholder = "new_order.phone_placeholder".localized
        static let emailOptionalPlaceholder = "new_order.email_optional_placeholder".localized
        static let imei = "new_order.imei".localized
        static let imeiPlaceholder = "new_order.imei_placeholder".localized
        static let searchCustomer = "new_order.search_customer".localized
        static let devicePoweredOn = "new_order.device_powered_on".localized
        static let devicePoweredOff = "new_order.device_powered_off".localized
        static let pinPattern = "new_order.pin_pattern".localized
        static let addModel = "new_order.add_model".localized
        static let addBrandPrompt = "new_order.add_brand_prompt".localized
        static let addModelPrompt = "new_order.add_model_prompt".localized
        static let customer = "new_order.customer".localized
        static let device = "new_order.device".localized
        static let problem = "new_order.problem".localized
        static let status = "new_order.status".localized
        static let diagnosis = "new_order.diagnosis".localized
        static func failsCount(_ fails: Int, _ total: Int) -> String {
            String(format: "new_order.fails_count".localized, fails, total)
        }
        static let createOrder = "new_order.create_order".localized
    }

    // MARK: - Print Label
    enum PrintLabel {
        static let title = "print_label.title".localized
        static let preview = "print_label.preview".localized
        static let size = "print_label.size".localized
        static let copies = "print_label.copies".localized
        static let print = "print_label.print".localized
        static let sharePdf = "print_label.share_pdf".localized
        static let sizeSmall = "print_label.size_small".localized
        static let sizeMedium = "print_label.size_medium".localized
        static let errorGenerating = "print_label.error_generating".localized
        static let errorSaving = "print_label.error_saving".localized
    }

    // MARK: - IMEI Scanner
    enum IMEIScanner {
        static let title = "imei_scanner.title".localized
        static let processing = "imei_scanner.processing".localized
        static let barcodeHint = "imei_scanner.barcode_hint".localized
        static let ocrHint = "imei_scanner.ocr_hint".localized
        static let imeiLocation = "imei_scanner.imei_location".localized
        static let switchOcr = "imei_scanner.switch_ocr".localized
        static let switchBarcode = "imei_scanner.switch_barcode".localized
        static func invalidFormat(_ digitCount: Int) -> String {
            "imei_scanner.invalid_format".localized(with: digitCount)
        }
    }

    // MARK: - Customers
    enum Customers {
        static let title = "customers.title".localized
        static let new = "customers.new".localized
        static let searchPlaceholder = "customers.search_placeholder".localized
        static let emptyTitle = "customers.empty_title".localized
        static let emptySubtitle = "customers.empty_subtitle".localized
        static let detailTitle = "customers.detail_title".localized
        static let editTitle = "customers.edit_title".localized
        static func customerSince(_ date: String) -> String {
            "customers.customer_since".localized(with: date)
        }
        static let noContactInfo = "customers.no_contact_info".localized
        static let edit = "customers.edit".localized
        static let delete = "customers.delete".localized
        static let deleteConfirmTitle = "customers.delete_confirm_title".localized
        static let deleteConfirmMessage = "customers.delete_confirm_message".localized
        static let sectionContact = "customers.section_contact".localized
        static let sectionNotes = "customers.section_notes".localized
        static let sectionInfo = "customers.section_info".localized
        static let namePlaceholder = "customers.name_placeholder".localized
        static let phonePlaceholder = "customers.phone_placeholder".localized
        static let emailPlaceholder = "customers.email_placeholder".localized
    }

    // MARK: - Settings
    enum Settings {
        static let title = "settings.title".localized
        static let workshopSection = "settings.workshop_section".localized
        static let name = "settings.name".localized
        static let phone = "settings.phone".localized
        static let orderPrefix = "settings.order_prefix".localized
        static let tax = "settings.tax".localized
        static let currency = "settings.currency".localized
        static let fiscalConfig = "settings.fiscal_config".localized
        static let tapToEdit = "settings.tap_to_edit".localized
        static let servicesSection = "settings.services_section".localized
        static let serviceCatalog = "settings.service_catalog".localized
        static let teamSection = "settings.team_section".localized
        static let manageTeam = "settings.manage_team".localized
        static let appSection = "settings.app_section".localized
        static let version = "settings.version".localized
        static let legalSection = "settings.legal_section".localized
        static let privacyPolicy = "settings.privacy_policy".localized
        static let termsOfService = "settings.terms_of_service".localized
        static let contactSupport = "settings.contact_support".localized
        static let logout = "settings.logout".localized
        static let logoutConfirmTitle = "settings.logout_confirm_title".localized
        static let logoutConfirmMessage = "settings.logout_confirm_message".localized
        static let logoutButton = "settings.logout_button".localized
        static let user = "settings.user".localized
        static let deleteAccount = "settings.delete_account".localized
        static let deleteAccountTitle = "settings.delete_account_title".localized
        static let deleteAccountMessage = "settings.delete_account_message".localized
        static let deleteAccountButton = "settings.delete_account_button".localized
        static let deleteAccountFooter = "settings.delete_account_footer".localized
    }

    // MARK: - Services
    enum Services {
        static let title = "services.title".localized
        static let add = "services.add".localized
        static let newTitle = "services.new_title".localized
        static let editTitle = "services.edit_title".localized
        static let searchPlaceholder = "services.search_placeholder".localized
        static let emptyTitle = "services.empty_title".localized
        static let emptySubtitle = "services.empty_subtitle".localized
        static let emptySearch = "services.empty_search".localized
        static let usedCount = "services.used_count".localized
        static let timesUsed = "services.times_used".localized
        static let lastUsed = "services.last_used".localized
        static let inactiveHint = "services.inactive_hint".localized
        static let deleteConfirm = "services.delete_confirm".localized
        static let deleteTitle = "services.delete_title".localized
        static let infoSection = "services.info_section".localized
        static let defaultPrice = "services.default_price".localized
        static let namePlaceholder = "services.name_placeholder".localized
        static let pricePlaceholder = "services.price_placeholder".localized
        static let type = "services.type".localized
        static let active = "services.active".localized
    }

    // MARK: - Workshop Edit
    enum WorkshopEdit {
        static let title = "workshop_edit.title".localized
        static let infoSection = "workshop_edit.info_section".localized
        static let workshopName = "workshop_edit.workshop_name".localized
        static let phone = "workshop_edit.phone".localized
        static let address = "workshop_edit.address".localized
        static let orderPrefix = "workshop_edit.order_prefix".localized
        static let fiscalSection = "workshop_edit.fiscal_section".localized
        static let taxName = "workshop_edit.tax_name".localized
        static let taxNamePlaceholder = "workshop_edit.tax_name_placeholder".localized
        static let taxRate = "workshop_edit.tax_rate".localized
        static let taxRatePlaceholder = "workshop_edit.tax_rate_placeholder".localized
        static let currencySection = "workshop_edit.currency_section".localized
        static let currencySymbol = "workshop_edit.currency_symbol".localized
        static let currencySymbolPlaceholder = "workshop_edit.currency_symbol_placeholder".localized
        static let currencyCode = "workshop_edit.currency_code".localized
        static let currencyCodePlaceholder = "workshop_edit.currency_code_placeholder".localized
        static let presetsSection = "workshop_edit.presets_section".localized
        static let presetsFooter = "workshop_edit.presets_footer".localized
        static let presetDR = "workshop_edit.preset_dr".localized
        static let presetMX = "workshop_edit.preset_mx".localized
        static let presetUS = "workshop_edit.preset_us".localized
    }

    // MARK: - Join Workshop
    enum JoinWorkshop {
        static let title = "join_workshop.title".localized
        static let codeTitle = "join_workshop.code_title".localized
        static let codeSubtitle = "join_workshop.code_subtitle".localized
        static let verifyButton = "join_workshop.verify_button".localized
        static let validTitle = "join_workshop.valid_title".localized
        static let joiningTo = "join_workshop.joining_to".localized
        static func asMember(_ role: String) -> String {
            "join_workshop.as_member".localized(with: role)
        }
        static let createAccountTitle = "join_workshop.create_account_title".localized
        static let createAccountSubtitle = "join_workshop.create_account_subtitle".localized
        static let createAndJoin = "join_workshop.create_and_join".localized
        static let invalidCode = "join_workshop.invalid_code".localized
        static let verifyError = "join_workshop.verify_error".localized
        static let acceptError = "join_workshop.accept_error".localized
        static let createError = "join_workshop.create_error".localized
        static let confirm = "join_workshop.confirm".localized
        static let createAccount = "join_workshop.create_account".localized
    }

    // MARK: - Team
    enum Team {
        static let title = "team.title".localized
        static func membersCount(_ count: Int) -> String {
            "team.members_count".localized(with: count)
        }
        static let members = "team.members".localized
        static let pendingInvites = "team.pending_invites".localized
        static let you = "team.you".localized
        static func inviteCode(_ code: String) -> String {
            "team.invite_code".localized(with: code)
        }
        static func expires(_ date: String) -> String {
            "team.expires".localized(with: date)
        }
    }

    // MARK: - Invite
    enum Invite {
        static let title = "invite.title".localized
        static let createdTitle = "invite.created_title".localized
        static let addToTeam = "invite.add_to_team".localized
        static let subtitle = "invite.subtitle".localized
        static let roleLabel = "invite.role_label".localized
        static let technician = "invite.technician".localized
        static let technicianDesc = "invite.technician_desc".localized
        static let admin = "invite.admin".localized
        static let adminDesc = "invite.admin_desc".localized
        static let generate = "invite.generate".localized
        static let readyTitle = "invite.ready_title".localized
        static let shareHint = "invite.share_hint".localized
        static func roleFormat(_ role: String) -> String {
            "invite.role_format".localized(with: role)
        }
        static let expires7Days = "invite.expires_7_days".localized
        static let share = "invite.share".localized
        static let copied = "invite.copied".localized
        static let copyCode = "invite.copy_code".localized
    }

    // MARK: - Quote
    enum Quote {
        static let noQuote = "quote.no_quote".localized
        static let createHint = "quote.create_hint".localized
        static let create = "quote.create".localized
        static let title = "quote.title".localized
        static let items = "quote.items".localized
        static func itemsCount(_ count: Int) -> String {
            "quote.items_count".localized(with: count)
        }
        static let addItemsHint = "quote.add_items_hint".localized
        static let addItem = "quote.add_item".localized
        static let editItem = "quote.edit_item".localized
        static let subtotal = "quote.subtotal".localized
        static let discount = "quote.discount".localized
        static let total = "quote.total".localized
        static let copyLink = "quote.copy_link".localized
        static let frequentServices = "quote.frequent_services".localized
        static let type = "quote.type".localized
        static let description = "quote.description".localized
        static let price = "quote.price".localized
        static let quantity = "quote.quantity".localized
        static let unitPrice = "quote.unit_price".localized
        static let status = "quote.status".localized
    }

    // MARK: - Offline
    enum Offline {
        static let noConnection = "offline.no_connection".localized
    }

    // MARK: - Status
    enum Status {
        static let received = "status.received".localized
        static let diagnosing = "status.diagnosing".localized
        static let quoted = "status.quoted".localized
        static let approved = "status.approved".localized
        static let inRepair = "status.in_repair".localized
        static let ready = "status.ready".localized
        static let delivered = "status.delivered".localized
    }

    // MARK: - Device Types
    enum DeviceType {
        static let iphone = "device.iphone".localized
        static let android = "device.android".localized
        static let tablet = "device.tablet".localized
        static let watch = "device.watch".localized
        static let laptop = "device.laptop".localized
        static let other = "device.other".localized
    }

    // MARK: - Roles
    enum Role {
        static let owner = "role.owner".localized
        static let admin = "role.admin".localized
        static let technician = "role.technician".localized
    }

    // MARK: - Workshop SignUp
    enum WorkshopSignUp {
        static let step1Title = "workshop_signup.step1_title".localized
        static let step1Subtitle = "workshop_signup.step1_subtitle".localized
        static let step2Title = "workshop_signup.step2_title".localized
        static let step2Subtitle = "workshop_signup.step2_subtitle".localized
        static let workshopName = "workshop_signup.workshop_name".localized
        static let phoneOptional = "workshop_signup.phone_optional".localized
        static let createButton = "workshop_signup.create_button".localized
    }

    // MARK: - Email Verification
    enum EmailVerification {
        static let title = "email_verification.title".localized
        static let sentTo = "email_verification.sent_to".localized
        static let checkInbox = "email_verification.check_inbox".localized
        static let resend = "email_verification.resend".localized
        static let backHome = "email_verification.back_home".localized
        static let resentSuccess = "email_verification.resent_success".localized
        static let resentTitle = "email_verification.resent_title".localized
    }

    // MARK: - Onboarding
    enum Onboarding {
        static let createdTitle = "onboarding.created_title".localized
        static func createdSubtitle(_ name: String) -> String {
            "onboarding.created_subtitle".localized(with: name)
        }
        static let basicConfig = "onboarding.basic_config".localized
        static let changeLater = "onboarding.change_later".localized
        static let currency = "onboarding.currency".localized
        static let orderPrefix = "onboarding.order_prefix".localized
        static func prefixPreview(_ prefix: String) -> String {
            "onboarding.prefix_preview".localized(with: prefix)
        }
        static let prefixPlaceholder = "onboarding.prefix_placeholder".localized
        static let allSetTitle = "onboarding.all_set_title".localized
        static let allSetSubtitle = "onboarding.all_set_subtitle".localized
        static let start = "onboarding.start".localized
    }

    // MARK: - Errors
    enum Error {
        static let network = "error.network".localized
        static let server = "error.server".localized
        static func serverWithCode(_ code: Int) -> String {
            "error.server_with_code".localized(with: code)
        }
        static let unauthorized = "error.unauthorized".localized
        static let notFound = "error.not_found".localized
        static let unknown = "error.unknown".localized
        static let invalidData = "error.invalid_data".localized
        static let timeout = "error.timeout".localized
        static let retry = "error.retry".localized
        static let creatingAccount = "error.creating_account".localized

        // Recovery suggestions
        static let networkSuggestion = "error.network_suggestion".localized
        static let serverSuggestion = "error.server_suggestion".localized
        static let unauthorizedSuggestion = "error.unauthorized_suggestion".localized
        static let timeoutSuggestion = "error.timeout_suggestion".localized
        static let retrySuggestion = "error.retry_suggestion".localized
    }

    // MARK: - Accessibility
    enum Accessibility {
        // Home
        static let newOrderHint = "accessibility.new_order_hint".localized
        static let profilePhoto = "accessibility.profile_photo".localized
        static let profilePhotoHint = "accessibility.profile_photo_hint".localized
        static func activeOrdersCard(_ total: Int, _ ready: Int) -> String {
            "accessibility.active_orders_card".localized(with: total, ready)
        }
        static func todayQuotesCard(_ count: Int, _ amount: String) -> String {
            "accessibility.today_quotes_card".localized(with: count, amount)
        }
        static func monthSummaryCard(_ month: String, _ received: Int, _ approved: Int, _ delivered: Int) -> String {
            "accessibility.month_summary_card".localized(with: month, received, approved, delivered)
        }

        // Orders
        static let viewOrderDetails = "accessibility.view_order_details".localized

        // Navigation
        static let goBack = "accessibility.go_back".localized
        static let closeSheet = "accessibility.close_sheet".localized

        // Forms
        static let requiredField = "accessibility.required_field".localized

        // Actions
        static let shareOrder = "accessibility.share_order".localized
        static let printLabel = "accessibility.print_label".localized
        static let changeStatus = "accessibility.change_status".localized
        static let callCustomer = "accessibility.call_customer".localized
        static let whatsappCustomer = "accessibility.whatsapp_customer".localized
    }
}
