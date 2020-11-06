DatabaseTest := UnitTest clone do (

    testValueFor := method(
        db := Database clone
        pkgName := "AFakePack"
        assertEquals(pkgName, db valueFor("AFakePack", "name"))
        assertEquals(
            "tests/_packs/AFakePack", 
            db valueFor("AFakePack", "url")))

)
