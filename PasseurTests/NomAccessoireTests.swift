import Testing

/// Le nom de la vignette de Maison : le service principal d'abord, l'accessoire a defaut.
@Suite("Nom de l'accessoire")
struct NomAccessoireTests {
    @Test("Le nom du service principal est utilise")
    func servicePrincipal() {
        #expect(NomAccessoire.affiche(accessoire: "Accessoire 1", servicePrincipal: "Vignette 1") == "Vignette 1")
    }

    @Test("Sans service principal, le nom de l'accessoire")
    func sansService() {
        #expect(NomAccessoire.affiche(accessoire: "Accessoire 1", servicePrincipal: nil) == "Accessoire 1")
    }

    @Test("Un nom de service vide ou blanc est ignore")
    func serviceVideOuBlanc() {
        #expect(NomAccessoire.affiche(accessoire: "Accessoire 1", servicePrincipal: "") == "Accessoire 1")
        #expect(NomAccessoire.affiche(accessoire: "Accessoire 1", servicePrincipal: "  \n ") == "Accessoire 1")
    }
}
