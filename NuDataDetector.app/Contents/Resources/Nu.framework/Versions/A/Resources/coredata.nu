;; @file coredata.nu
;; @discussion Nu extensions for programming with Core Data.
;;
;; @copyright Copyright (c) 2007 Tim Burks, Neon Design Technology, Inc.

;; @class NuCoreDataSession
;; @discussion Instances of this class can be used to manage CoreData sessions.
;; They encapsulate the three major elements of a CoreData session: the managed
;; object model, the persistent store coordinator, and the managed object context.
;; While at times it may be useful to treat these three elements separately, in
;; many situations, that needlessly complicates the use of CoreData.  With the
;; methods of this class and the accompanying extensions to NSManagedObject, it
;; is very easy to use CoreData from Nu.
(class NuCoreDataSession is NSObject
     (ivars)
     
     ;; Create a session with a specified model and SQLite store file.
     (imethod (id) initWithName:(id) name mom:(id)momFile sqliteStore:(id)storeFile is
          (super init)
          (set @name name)
          (set @momFile momFile)
          (set @momURL (NSURL fileURLWithPath:@momFile))
          (set @storeFile storeFile)
          (set @storeType NSSQLiteStoreType)
          (set @storeURL (NSURL fileURLWithPath:@storeFile))
          self)
     
     ;; Create a session with a specified model and XML store file.
     (imethod (id) initWithName:(id) name mom:(id)momFile xmlStore:(id)storeFile is
          (super init)
          (set @name name)
          (set @momFile momFile)
          (set @momURL (NSURL fileURLWithPath:@momFile))
          (set @storeFile storeFile)
          (set @storeType NSXMLStoreType)
          (set @storeURL (NSURL fileURLWithPath:@storeFile))
          self)
     
     ;; Save the session's managed object context.
     (imethod (id) save is
          (unless (set result ((self managedObjectContext) save:(set perror ((NuReference alloc) init))))
                  (NSLog "error saving: #{((perror value) localizedDescription)}"))
          result)
     
     ;; Get the managed object model, initializing it if necessary.
     (imethod (id) managedObjectModel is
          (unless (@mom)
                  (set @mom ((NSManagedObjectModel alloc) initWithContentsOfURL:@momURL)))
          @mom)
     
     ;; Get the persistent store coordinator, initializing it if necessary.
     (imethod (id) persistentStoreCoordinator is
          (unless @psc
                  (set @psc ((NSPersistentStoreCoordinator alloc) initWithManagedObjectModel:(self managedObjectModel)))
                  (unless (@psc addPersistentStoreWithType:@storeType
                                configuration:nil
                                URL:@storeURL
                                options:(NSDictionary dictionary)
                                error:(set perror ((NuReference alloc) init)))
                          (NSLog "error opening persistent store: #{((perror value) localizedDescription)}")))
          @psc)
     
     ;; Get the managed object context, initializing it if necessary.
     (imethod (id) managedObjectContext is
          (unless @moc
                  (set coordinator (self persistentStoreCoordinator))
                  (if coordinator
                      (set @moc ((NSManagedObjectContext alloc) init))
                      (@moc setPersistentStoreCoordinator:coordinator)))
          @moc)
     
     ;; Create an object for a specified entity.
     (imethod (id) createObjectWithEntity:(id) entityName is
          (NSEntityDescription
                              insertNewObjectForEntityForName:entityName
                              inManagedObjectContext:(self managedObjectContext)))
     
     ;; Find or create an object with the property values in a specified list.
     (imethod (id) findOrCreateObjectWithEntity:(id) entityName propertyValues:(id)pairs is
          (set matches (self objectsWithEntity:entityName propertyValues:pairs))
          (if (matches count)
              (then (matches 0))
              (else (set object (self createObjectWithEntity:entityName))
                    (object set:pairs))))
     
     ;; Get all objects in the session's context.
     (imethod (id) objects is
          (set objects (NSMutableSet set))
          (((self managedObjectModel) entities) each:
           (do (entity)
               (set fetch ((NSFetchRequest alloc) init))
               (fetch setEntity:entity)
               (set result ((self managedObjectContext) executeFetchRequest:fetch error:nil))
               (objects addObjectsFromArray:result)))
          objects)
     
     ;; Get all objects of a specified entity.
     (imethod (id) objectsWithEntity:(id) entityName is
          (set f ((NSFetchRequest alloc) init))
          (f setEntity:(((self managedObjectModel) entitiesByName) objectForKey:entityName))
          (((self managedObjectContext)) executeFetchRequest:f error:nil))
     
     ;; Get any object with a specified entity.
     (imethod (id) anyObjectWithEntity:(id) entityName is
          (set f ((NSFetchRequest alloc) init))
          (f setFetchLimit:1)
          (f setEntity:(((self managedObjectModel) entitiesByName) objectForKey:entityName))
          ((((self managedObjectContext)) executeFetchRequest:f error:nil) 0))
     
     ;; Get all objects of a specified entity with a given property value.
     (imethod (id) objectsWithEntity:(id) entityName property:(id) property value:(id) value is
          (set f ((NSFetchRequest alloc) init))
          (f setEntity:(((self managedObjectModel) entitiesByName) objectForKey:entityName))
          (set p (NSPredicate predicateWithFormat:"#{property} = '#{value}'"))
          (f setPredicate: p)
          ((self managedObjectContext) executeFetchRequest:f error:nil))
     
     ;; Get all objects of a specified entity with the property values in a specified list.
     (imethod (id) objectsWithEntity:(id) entityName propertyValues:(id)pairs is
          (set f ((NSFetchRequest alloc) init))
          (f setEntity:(((self managedObjectModel) entitiesByName) objectForKey:entityName))
          (set predicates (NSMutableArray array))
          (pairs eachPair:
                 (do (property value)
                     (predicates addObject:
                          (NSPredicate predicateWithFormat:"#{(property labelName)} = '#{value}'"))))
          (f setPredicate: (NSCompoundPredicate andPredicateWithSubpredicates:predicates))
          ((self managedObjectContext) executeFetchRequest:f error:nil))
     
     ;; Get all objects of a specified entity with the property values in a specified list, sorted.
     (imethod (id) objectsWithEntity:(id) entityName propertyValues:(id)pairs sortDescriptors:(id)sortDescriptors is
          (set f ((NSFetchRequest alloc) init))
          (f setEntity:(((self managedObjectModel) entitiesByName) objectForKey:entityName))
          (set predicates (NSMutableArray array))
          (pairs eachPair:
                 (do (property value)
                     (predicates addObject:
                          (NSPredicate predicateWithFormat:"#{(property labelName)} = '#{value}'"))))
          (f setPredicate: (NSCompoundPredicate andPredicateWithSubpredicates:predicates))
          (f setSortDescriptors: sortDescriptors)
          ((self managedObjectContext) executeFetchRequest:f error:nil))
     
     ;; Get an array of entities in the managed object model.
     (imethod (id) entities is
          ((self managedObjectModel) entities))
     
     ;; Get an entity with a specified name.
     (imethod (id) entityWithName:(id) name is
          (((self managedObjectModel) entitiesByName) objectForKey:name))
     
     ;; Get an object with a specified entity and identifier.
     ;; This method allows an object to be associated with a short integer identifier.
     ;; Identifiers are represented as NSStrings.
     ;; It works by extracting the identifier from the object's URIRepresentation.
     ;; If the implementation of URIRepresentation changes, this will break.
     (imethod (id) objectWithEntity:(id) entityName identifier:(id) identifier is
          (set prefixParts
               (((((self anyObjectWithEntity:entityName) objectID) URIRepresentation) absoluteString) componentsSeparatedByString:"/"))
          (set prefix ((prefixParts subarrayWithRange:(list 0 (- (prefixParts count) 2))) componentsJoinedByString:"/"))
          (set uri (NSURL URLWithString:"#{prefix}/#{entityName}/p#{identifier}"))
          (set objectID (@psc managedObjectIDForURIRepresentation:uri))
          (if (@moc objectRegisteredForID:objectID)
              (then (@moc objectWithID:objectID))
              (else nil))))

;; ActiveRecord-style extensions to NSManagedObject.
;; These are most useful for entity-specific subclasses of NSManagedObject.
;; When an entity is looked up by name, it must be defined in the application delegate's managed object model.
(class NSManagedObject
     
     ;; Return non-nil if the object has a property for the specified key
     (imethod (id) hasValueForKey:(id) key is
          (((self entity) propertiesByName) valueForKey:key))
     
     ;; Attempt to use the name of an unknown message as a key.
     (imethod (id) handleUnknownMessage:(id) method withContext:(id) context is
          (set methodName ((method car) stringValue))
          (try
              (self valueForKey:methodName)
              (catch (exception) ;; if anything went wrong, pass the message up
                     (super handleUnknownMessage:method withContext:context))))
     
     ;; Delete an object.
     (imethod (id) delete is
          ((self managedObjectContext) deleteObject:self))
     
     ;; Create an object for the entity with the same name as this class.
     (cmethod (id) createObject is
          (self createObjectWithEntity:((self class) name)))
     
     ;; Create an object for a named entity.
     (cmethod (id) createObjectWithEntity:(id) entityName is
          (NSEntityDescription
                              insertNewObjectForEntityForName:entityName
                              inManagedObjectContext:(((NSApplication sharedApplication) delegate) managedObjectContext)))
     
     ;; Find objects using the class name as the entity name.
     (cmethod (id) objects is
          (self objectsWithEntity:((self class) name)))
     
     ;; Find objects with a specified property value using the class name as the entity name.
     (cmethod (id) objectWithProperty:(id) property value:(id) value is
          (set result (self objectsWithProperty:property value:value))
          (if (and result (> (result count) 0))
              (then (result 0))
              (else nil)))
     
     ;; Find objects with a specified property value using the class name as the entity name.
     (cmethod (id) objectsWithProperty:(id) property value:(id) value is
          (self objectsWithEntity:((self class) name) property:property value:value))
     
     ;; Find objects with specified property values and sort descriptors using the class name as the entity name.
     (cmethod (id) objectsWithPropertyValues:(id)pairs sortDescriptors:(id)sortDescriptors is
          (self objectsWithEntity:((self class) name) propertyValues:pairs sortDescriptors:sortDescriptors))
     
     ;; Find objects of a named entity.
     (cmethod (id) objectsWithEntity:(id) entityName is
          (set f ((NSFetchRequest alloc) init))
          (f setEntity:(((((NSApplication sharedApplication) delegate) managedObjectModel) entitiesByName) objectForKey:entityName))
          (set result (((((NSApplication sharedApplication) delegate) managedObjectContext)) executeFetchRequest:f error:nil))
          result)
     
     ;; Find objects of a named entity with a specified property value.
     (cmethod (id) objectsWithEntity:(id) entityName property:(id) property value:(id) value is
          (set f ((NSFetchRequest alloc) init))
          (f setEntity:(((((NSApplication sharedApplication) delegate) managedObjectModel) entitiesByName) objectForKey:entityName))
          (set p (NSPredicate predicateWithFormat:"#{property} = '#{value}'"))
          (f setPredicate: p)
          ((((NSApplication sharedApplication) delegate) managedObjectContext) executeFetchRequest:f error:nil))
     
     ;; Find objects of a named entity with specified property values and sort descriptors.
     (cmethod (id) objectsWithEntity:(id) entityName propertyValues:(id)pairs sortDescriptors:(id)sortDescriptors is
          (set f ((NSFetchRequest alloc) init))
          (f setEntity:(((((NSApplication sharedApplication) delegate) managedObjectModel) entitiesByName) objectForKey:entityName))
          (set predicates (NSMutableArray array))
          (pairs eachPair:(do (property value)
                              (predicates addObject:
                                   (NSPredicate predicateWithFormat:"#{(property labelName)} = #{value}"))))
          (f setPredicate: (NSCompoundPredicate andPredicateWithSubpredicates:predicates))
          (f setSortDescriptors: sortDescriptors)
          (set result (((((NSApplication sharedApplication) delegate) managedObjectContext)) executeFetchRequest:f error:nil))
          result)
     
     ;; Get an object with a specified identifier and the entity with the same name as this class.
     ;; This method allows an object to be associated with a short integer identifier.
     ;; Identifiers are represented as NSStrings.
     ;; It works by extracting the identifier from the object's URIRepresentation.
     ;; If the implementation of URIRepresentation changes, this will break.
     (cmethod (id) objectWithIdentifier:(id) identifier is
          ((((NSApplication sharedApplication) delegate) session) objectWithEntity: ((self class) name) identifier:identifier))
     
     ;; Get an identifier for an object.
     ;; This method allows an object to be associated with a short integer identifier.
     ;; Identifiers are represented as NSStrings.
     ;; It works by extracting the identifier from the object's URIRepresentation.
     ;; If the implementation of URIRepresentation changes, this will break.
     (imethod (id) identifier is ;; DANGER! This assumes the syntax of URI representations is reliable.
          (if ((self objectID) isTemporaryID) ($session save))
          ((((((self objectID) URIRepresentation) resourceSpecifier)
             componentsSeparatedByString:"/") 4) substringFromIndex:1)))
