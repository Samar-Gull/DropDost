import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/order_model.dart';
import '../providers/auth_provider.dart';
import '../providers/database_service.dart';

class CreateOrderScreen extends StatefulWidget {
  const CreateOrderScreen({super.key});

  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  static const LatLng _defaultLocation = LatLng(33.6844, 73.0479);

  final _formKey = GlobalKey<FormState>();

  final _pickupAddressController = TextEditingController();
  final _pickupContactController = TextEditingController();
  final _pickupPhoneController = TextEditingController();

  final _deliveryAddressController = TextEditingController();
  final _deliveryContactController = TextEditingController();
  final _deliveryPhoneController = TextEditingController();

  final _descriptionController = TextEditingController();

  LatLng? _pickupLocation;
  LatLng? _deliveryLocation;
  String _parcelSize = 'small';
  bool _isLoading = false;

  @override
  void dispose() {
    _pickupAddressController.dispose();
    _pickupContactController.dispose();
    _pickupPhoneController.dispose();
    _deliveryAddressController.dispose();
    _deliveryContactController.dispose();
    _deliveryPhoneController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  double _calculateAmount() {
    switch (_parcelSize) {
      case 'small':
        return 120;
      case 'medium':
        return 180;
      case 'large':
        return 250;
      default:
        return 120;
    }
  }

  Future<void> _createOrder() async {
    if (!_formKey.currentState!.validate()) return;

    if (_pickupLocation == null || _deliveryLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select pickup and delivery maps')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final authService = Provider.of<AuthService>(context, listen: false);
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final pickup = _pickupLocation!;
    final delivery = _deliveryLocation!;

    final order = OrderModel(
      orderId: const Uuid().v4(),
      customerId: authService.currentUser!.uid,
      pickupAddress: _pickupAddressController.text.trim(),
      pickupLat: pickup.latitude,
      pickupLng: pickup.longitude,
      pickupContact: _pickupContactController.text.trim(),
      pickupPhone: _pickupPhoneController.text.trim(),
      deliveryAddress: _deliveryAddressController.text.trim(),
      deliveryLat: delivery.latitude,
      deliveryLng: delivery.longitude,
      deliveryContact: _deliveryContactController.text.trim(),
      deliveryPhone: _deliveryPhoneController.text.trim(),
      parcelSize: _parcelSize,
      description: _descriptionController.text.trim(),
      amount: _calculateAmount(),
      status: 'pending',
      createdAt: DateTime.now(),
    );

    try {
      await dbService.createOrder(order);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order created successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectLocation({
    required String title,
    required TextEditingController controller,
    required bool isPickup,
  }) async {
    final initialLocation =
        (isPickup ? _pickupLocation : _deliveryLocation) ??
        await _getInitialMapTarget();

    if (!mounted) return;

    final selection = await showDialog<_PickedLocation>(
      context: context,
      builder: (context) => _LocationPickerDialog(
        title: title,
        initialAddress: controller.text,
        initialLocation: initialLocation,
      ),
    );

    if (selection == null || !mounted) return;

    setState(() {
      controller.text = selection.address;
      if (isPickup) {
        _pickupLocation = selection.location;
      } else {
        _deliveryLocation = selection.location;
      }
    });
  }

  Future<LatLng> _getInitialMapTarget() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return _defaultLocation;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return _defaultLocation;
      }

      final position = await Geolocator.getCurrentPosition();
      return LatLng(position.latitude, position.longitude);
    } catch (_) {
      return _defaultLocation;
    }
  }

  String? _validatePhone(String? value) {
    final phone = value?.trim() ?? '';
    if (phone.isEmpty) return 'Required';
    if (!RegExp(r'^\d{11}$').hasMatch(phone)) {
      return 'Enter exactly 11 digits';
    }
    return null;
  }

  List<TextInputFormatter> get _phoneInputFormatters => [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(11),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Order')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pickup Details',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _pickupAddressController,
                readOnly: true,
                onTap: () => _selectLocation(
                  title: 'Pickup Location',
                  controller: _pickupAddressController,
                  isPickup: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Pickup Address',
                  prefixIcon: Icon(Icons.location_on_outlined),
                  suffixIcon: Icon(Icons.map_outlined),
                ),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _pickupContactController,
                decoration: const InputDecoration(
                  labelText: 'Contact Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _pickupPhoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                keyboardType: TextInputType.phone,
                inputFormatters: _phoneInputFormatters,
                validator: _validatePhone,
              ),
              const SizedBox(height: 32),
              Text(
                'Delivery Details',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _deliveryAddressController,
                readOnly: true,
                onTap: () => _selectLocation(
                  title: 'Delivery Location',
                  controller: _deliveryAddressController,
                  isPickup: false,
                ),
                decoration: const InputDecoration(
                  labelText: 'Delivery Address',
                  prefixIcon: Icon(Icons.location_on_outlined),
                  suffixIcon: Icon(Icons.map_outlined),
                ),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _deliveryContactController,
                decoration: const InputDecoration(
                  labelText: 'Contact Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _deliveryPhoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                inputFormatters: _phoneInputFormatters,
                keyboardType: TextInputType.phone,
                validator: _validatePhone,
              ),
              const SizedBox(height: 32),
              Text(
                'Parcel Details',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text('Size:', style: Theme.of(context).textTheme.titleMedium),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('Small'),
                      subtitle: const Text('Rs. 120'),
                      value: 'small',
                      // ignore: deprecated_member_use
                      groupValue: _parcelSize,
                      // ignore: deprecated_member_use
                      onChanged: (v) => setState(() => _parcelSize = v!),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('Medium'),
                      subtitle: const Text('Rs. 180'),
                      value: 'medium',
                      // ignore: deprecated_member_use
                      groupValue: _parcelSize,
                      // ignore: deprecated_member_use
                      onChanged: (v) => setState(() => _parcelSize = v!),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
              RadioListTile<String>(
                title: const Text('Large'),
                subtitle: const Text('Rs. 250'),
                value: 'large',
                // ignore: deprecated_member_use
                groupValue: _parcelSize,
                // ignore: deprecated_member_use
                onChanged: (v) => setState(() => _parcelSize = v!),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  prefixIcon: Icon(Icons.description_outlined),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Estimated Cost:',
                      style: TextStyle(fontSize: 16),
                    ),
                    Text(
                      'Rs. ${_calculateAmount().toInt()}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2ECC71),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createOrder,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('CREATE ORDER'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickedLocation {
  final String address;
  final LatLng location;

  const _PickedLocation({required this.address, required this.location});
}

class _LocationPickerDialog extends StatefulWidget {
  final String title;
  final String initialAddress;
  final LatLng initialLocation;

  const _LocationPickerDialog({
    required this.title,
    required this.initialAddress,
    required this.initialLocation,
  });

  @override
  State<_LocationPickerDialog> createState() => _LocationPickerDialogState();
}

class _LocationPickerDialogState extends State<_LocationPickerDialog> {
  late final TextEditingController _searchController;
  late LatLng _selectedLocation;
  GoogleMapController? _mapController;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
    _searchController = TextEditingController(text: widget.initialAddress);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchAddress() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() => _isSearching = true);

    try {
      final locations = await locationFromAddress(query);
      if (locations.isEmpty) {
        _showMessage('Location not found');
        return;
      }

      final location = LatLng(
        locations.first.latitude,
        locations.first.longitude,
      );
      await _setSelectedLocation(location, updateAddress: false);
      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(location, 15),
      );
    } catch (e) {
      _showMessage('Location search failed: $e');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _useCurrentLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showMessage('Location permission is required');
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      final location = LatLng(position.latitude, position.longitude);
      await _setSelectedLocation(location);
      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(location, 16),
      );
    } catch (e) {
      _showMessage('Could not get current location: $e');
    }
  }

  Future<void> _setSelectedLocation(
    LatLng location, {
    bool updateAddress = true,
  }) async {
    setState(() => _selectedLocation = location);

    if (!updateAddress) return;

    final address = await _reverseAddress(location);
    if (!mounted || address == null) return;

    setState(() => _searchController.text = address);
  }

  Future<String?> _reverseAddress(LatLng location) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );
      if (placemarks.isEmpty) return null;

      final place = placemarks.first;
      final parts = [
        place.street,
        place.subLocality,
        place.locality,
        place.administrativeArea,
      ].where((part) => part != null && part.trim().isNotEmpty).cast<String>();

      return parts.join(', ');
    } catch (_) {
      return null;
    }
  }

  Future<void> _confirmSelection() async {
    var address = _searchController.text.trim();
    address = address.isEmpty
        ? await _reverseAddress(_selectedLocation) ??
              '${_selectedLocation.latitude}, ${_selectedLocation.longitude}'
        : address;

    if (!mounted) return;

    Navigator.pop(
      context,
      _PickedLocation(address: address, location: _selectedLocation),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _searchAddress(),
                decoration: InputDecoration(
                  hintText: 'Search location',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _isSearching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          onPressed: _searchAddress,
                          icon: const Icon(Icons.arrow_forward),
                        ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _useCurrentLocation,
                  icon: const Icon(Icons.my_location),
                  label: const Text('Use Current Location'),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _selectedLocation,
                  zoom: 14,
                ),
                markers: {
                  Marker(
                    markerId: const MarkerId('selected_location'),
                    position: _selectedLocation,
                  ),
                },
                onMapCreated: (controller) => _mapController = controller,
                onTap: _setSelectedLocation,
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                zoomControlsEnabled: false,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _confirmSelection,
                  child: const Text('USE THIS LOCATION'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
