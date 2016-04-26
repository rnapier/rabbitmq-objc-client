import XCTest

class ConnectionClosureTest: XCTestCase {

    func testCloseClosesAllChannels() {
        let transport = ControlledInteractionTransport()
        let allocator = ChannelSpyAllocator()
        let q = FakeSerialQueue()
        let handshakeCount = 1
        let expectedCloseProcedureCount = 4
        let channelsToCreateCount = 2
        let conn = RMQConnection(transport: transport, user: "", password: "", vhost: "", channelMax: 10, frameMax: 11, heartbeat: 12, handshakeTimeout: 2, channelAllocator: allocator, frameHandler: FrameHandlerSpy(), delegate: ConnectionDelegateSpy(), commandQueue: q, waiterFactory: FakeWaiterFactory())

        conn.start()
        try! q.step()
        transport.handshake()

        for _ in 1...channelsToCreateCount {
            conn.createChannel()
        }

        conn.close()

        for _ in 1...channelsToCreateCount {
            try! q.step()
        }

        XCTAssertEqual(handshakeCount + channelsToCreateCount + expectedCloseProcedureCount, q.items.count)

        try! q.step()

        XCTAssertFalse(allocator.channels[0].blockingCloseCalled)
        XCTAssertTrue(allocator.channels[1].blockingCloseCalled)
        XCTAssertTrue(allocator.channels[2].blockingCloseCalled)
    }

    func testCloseSendsCloseMethod() {
        let (transport, q, conn, _) = TestHelper.connectionAfterHandshake()

        conn.close()

        try! q.step()
        try! q.step()

        transport.assertClientSentMethod(MethodFixtures.connectionClose(), channelNumber: 0)
    }

    func testCloseWaitsForCloseOkOnChannelZero() {
        let transport = ControlledInteractionTransport()
        let allocator = ChannelSpyAllocator()
        let q = FakeSerialQueue()
        let conn = RMQConnection(transport: transport, user: "", password: "", vhost: "", channelMax: 10, frameMax: 11, heartbeat: 12, handshakeTimeout: 2, channelAllocator: allocator, frameHandler: FrameHandlerSpy(), delegate: ConnectionDelegateSpy(), commandQueue: q, waiterFactory: FakeWaiterFactory())

        conn.close()

        try! q.step()
        try! q.step()

        XCTAssertNil(allocator.channels[0].blockingWaitOnMethod)
        try! q.step()
        XCTAssertEqual("RMQConnectionCloseOk", allocator.channels[0].blockingWaitOnMethod!.description())
    }

    func testCloseClosesTransport() {
        let (transport, q, conn, _) = TestHelper.connectionAfterHandshake()

        conn.close()

        try! q.step()
        try! q.step()
        try! q.step()

        XCTAssertTrue(transport.connected)
        try! q.step()
        XCTAssertFalse(transport.connected)
    }

    func testBlockingCloseIsANormalCloseButBlocking() {
        let transport = ControlledInteractionTransport()
        let allocator = ChannelSpyAllocator()
        let q = FakeSerialQueue()
        let expectedCloseProcedureCount = 4
        let channelsToCreateCount = 2
        let conn = RMQConnection(transport: transport, user: "", password: "", vhost: "", channelMax: 10, frameMax: 11, heartbeat: 12, handshakeTimeout: 2, channelAllocator: allocator, frameHandler: FrameHandlerSpy(), delegate: ConnectionDelegateSpy(), commandQueue: q, waiterFactory: FakeWaiterFactory())

        conn.start()
        try! q.step()
        transport.handshake()

        for _ in 1...channelsToCreateCount {
            conn.createChannel()
        }

        conn.blockingClose()

        for _ in 1...channelsToCreateCount {
            try! q.step()
        }

        XCTAssertEqual(expectedCloseProcedureCount, q.blockingItems.count)

        try! q.step()

        XCTAssertFalse(allocator.channels[0].blockingCloseCalled)
        XCTAssertTrue(allocator.channels[1].blockingCloseCalled)
        XCTAssertTrue(allocator.channels[2].blockingCloseCalled)

        try! q.step()

        XCTAssertEqual(MethodFixtures.connectionClose(), transport.lastSentPayload() as? RMQConnectionClose)

        try! q.step()

        XCTAssertEqual("RMQConnectionCloseOk", allocator.channels[0].blockingWaitOnMethod!.description())

        try! q.step()

        XCTAssertFalse(transport.connected)
    }

    func testServerInitiatedClosing() {
        let (transport, _, _, _) = TestHelper.connectionAfterHandshake()

        transport.serverSendsPayload(MethodFixtures.connectionClose(), channelNumber: 0)
        
        XCTAssertFalse(transport.isConnected())
        transport.assertClientSentMethod(MethodFixtures.connectionCloseOk(), channelNumber: 0)
    }

}
