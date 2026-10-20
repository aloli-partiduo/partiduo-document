# SPDX-License-Identifier: AGPL-3.0-or-later

require "../spec_helper"

# Traductions des écrans de l'extension (ADR-005 D7) : chaque route de
# `/ext/DOCUMENT/` servie en `GET` (liste tirée du routeur de Marten),
# obtenue en fr, en et nl par un administrateur, sur une boîte variée :
# photo à traiter (fournisseur reconnu), PDF sans compléments, facture
# reçue de la plateforme (données structurées), justificatif écarté et
# justificatif rattaché à son écriture. Contrôle de l'interface
# (`PartiduoUi::Translations`) : ni marqueur de traduction absente, ni clé
# brute, ni interpolation non résolue, et toute route atteinte par les
# liens des pages.

private alias Api = Document::Api
private alias S = Document::SpecSupport
private alias Books = PartiduoUi::Books

describe "Traductions des écrans DOCUMENT (fr, en, nl)" do
  it "rend chaque écran dans chaque langue, sans clé absente, brute ni interpolation non résolue" do
    browser = Books.admin
    S.activate
    Books.card("SUPPLIER", "Orange Business", "FOUR-ORANGE")
    S.capture(S.jpeg, "ticket.jpg", Api::DetailsInput.new(supplier_name: "Station Total", amount: S.d("68.52"),
      date: S.date("2026-09-25"), kind: "ticket", note: "Carburant"))
    S.capture(S::PDF, "facture.pdf")
    Api.receive(Partiduo::Api::Actor.system, Api::ReceiveInput.new(filename: "FB-4471.pdf", content: S::PDF,
      external_ref: "superpdp:4471", details: Api::DetailsInput.new(supplier_name: "Orange Business", amount: S.d("86.40"),
      date: S.date("2026-09-24"), reference: "FB-4471"), data_filename: "FB-4471.xml", data: S::XML)).value!
    discarded = S.capture(S.jpeg, "doublon.jpg")
    Api.discard(S.admin, discarded.id).value!
    attached = S.capture(S::PDF, "FB-4472.pdf", Api::DetailsInput.new(supplier_code: "FOUR-ORANGE", amount: S.d("86.40"),
      date: S.date("2026-09-24"), reference: "FB-4472"))
    browser.post("/ext/DOCUMENT/#{attached.id}/entry", {"ledger_id" => Books.ledger("A01").id.to_s, "date" => "24/09/2026",
                                                        "receipt" => "", "third_party" => "FOUR-ORANGE", "due_date" => "", "label" => "Orange · fibre",
                                                        "line-0-account" => "603", "line-0-label" => "Fibre", "line-0-amount" => "72",
                                                        "line-0-vat_rate" => "NOR", "invoice_number" => "FB-4472"}).status.should eq(302)

    explorer = PartiduoUi::Translations::Explorer.new(&.name.starts_with?("document:"))
    # Les requêtes laissent active la dernière langue obtenue (nl) : la
    # langue d'avant est rendue aux exemples suivants.
    locale = I18n.locale
    begin
      explorer.crawl(browser, "DOCUMENT")
    ensure
      I18n.activate(locale)
    end
    puts "\nTraductions de DOCUMENT : #{explorer.report}"
    (explorer.failures + explorer.unreached.map { |route| "route jamais atteinte : #{route}" }).should eq([] of String)
  end
end
